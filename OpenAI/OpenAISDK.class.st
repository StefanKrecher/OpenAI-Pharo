"
Class: OpenAISDK

I represent a class that interacts with the OpenAI API.

Responsibilities:
- I create an instance of the OpenAISDK class with the provided API key and organization.
- I set the necessary headers for authentication and content type.
- I provide a method to open the usage page of the OpenAI platform.

Collaborators:
- ZnClient: I use ZnClient to create a new client instance and set headers for authentication and content type.
- WebBrowser: I use WebBrowser to open the usage page of the OpenAI platform.

Examples:
- ""Create an instance of OpenAISDK with an API key: OpenAISDK createWithAPIKey: 'your_api_key_here'""
- ""Open the usage page of the OpenAI platform: OpenAISDK openUsagePage""


[This comment was automatically created with https://github.com/brackendev/OpenAI-Pharo]
"
Class {
	#name : 'OpenAISDK',
	#superclass : 'Object',
	#instVars : [
		'client',
		'responseJson'
	],
	#category : 'OpenAI-Core',
	#package : 'OpenAI',
	#tag : 'Core'
}

{ #category : 'public' }
OpenAISDK class >> createRealtimeWithAPIKey: anAPIKeyString [

	"Get an API key at https://platform.openai.com/account/api-keys"

	"https://platform.openai.com/docs/api-reference/authentication"

	| client |
	client := ZnClient new.
	client headerAt: 'Content-Type' put: 'application/json'.
	client headerAt: 'Authorization' put: 'Bearer ' , anAPIKeyString.
	client headerAt: 'OpenAI-Beta' put: 'realtime=v1'.
	client method: #GET;
		headerAt: 'Upgrade' put: 'websocket';
		headerAt: 'Connection' put: 'Upgrade';
		headerAt: 'Sec-WebSocket-Version' put: '13';
		headerAt: 'Sec-WebSocket-Key' put: ZnWebSocketUtils newClientKey.
	client url: 'wss://api.openai.com/v1/realtime?model=gpt-4o-realtime-preview-2024-10-01'.
	client execute.
	^ZnWebSocket onClient: client.
]

{ #category : 'public' }
OpenAISDK class >> createWithAPIKey: anAPIKeyString [

	^ self createWithAPIKey: anAPIKeyString organization: nil
]

{ #category : 'public' }
OpenAISDK class >> createWithAPIKey: anAPIKeyString organization: anOrganizationString [

	"Get an API key at https://platform.openai.com/account/api-keys"

	"https://platform.openai.com/docs/api-reference/authentication"

	| client |
	client := ZnClient new.
	client headerAt: 'Content-Type' put: 'application/json'.
	client headerAt: 'Authorization' put: 'Bearer ' , anAPIKeyString.
	anOrganizationString isNotNil ifTrue: [ 
		client headerAt: 'OpenAI-Organization' put: anOrganizationString ].
	client timeout: 60.
	^ self new client: client
]

{ #category : 'public' }
OpenAISDK class >> openUsagePage [

	WebBrowser openOn: 'https://platform.openai.com/account/usage'
]

{ #category : 'private' }
OpenAISDK >> baseURL [ 
^ 'https://api.openai.com/v1'
]

{ #category : 'accessing' }
OpenAISDK >> client [

	^ client
]

{ #category : 'accessing' }
OpenAISDK >> client: anObject [

	client := anObject
]

{ #category : 'public' }
OpenAISDK >> createAudioWithInput: anInputString model: aModelString voice: aVoiceString [

	| json processes clients results startTimes waitSemaphore result |

	"Create JSON input structure"
	json := NeoJSONWriter toString: {
		#input -> anInputString.
		#model -> aModelString.
		#voice -> aVoiceString } asDictionary.

	"Create a set of Processes with a new client (to prevent using the same client instance in multiple
	processes). Each Process is created with a Delay to start the cliebt. As soon as a client has received
	a full response, the other Processes and client(s) are stopped. Each Process stores its result in a
	separate location. In this same location any error that occurred, will also be stored."
	processes := Array new: 3.
	clients := Array new: processes size.
	results := Array new: processes size.
	startTimes := #(0 5 15).
	result := nil.

	"Create a Semaphore to let (this) owning Process wait for subprocesses"
	waitSemaphore := Semaphore new.

	"Start up all Processes (only one will become active, others will start waiting).
	Each Process will normally end with a signal to (wake up of) the owning Process."
	1 to: processes size do: [ :index |
		processes at: index put: [

			"Wrap code in error handler for any exceptions during communication"
			[
				| localClient |

				"Perform delay before starting actual work"
				(Delay forSeconds: (startTimes at: index)) wait.

				"Start a new client"
				localClient := self createStreamingAudioClientOn: json.

				"Register the new client and start streaming the result"
				clients at: index put: localClient.
				results at: index put: localClient execute upToEnd.

				"Results is received, wake up the owning Process"
				waitSemaphore signal.
			] on: Error do: [ :error |

				"Store error in result"
				results at: index put: (OpenAIParallelClientError error: error).

				"Wake up the owning Process"
				waitSemaphore signal ] ] fork ].

	"Start waiting for any of the subprocesses"
	[ processes anySatisfy: [ :each | each isNotNil ] ] whileTrue: [

		"Wait for a signal"
		waitSemaphore wait.

		"Handle results and/or errors"
		results withIndexDo: [ :each :index |
			| removeFrom removeTo |

			"Remember if we want to remove result entries (and related items)"
			removeFrom := 0.
			removeTo := -1.

			"Distinguish error and valid result"
			each class == OpenAIParallelClientError
				ifTrue: [
					"Log error"
					self errorCr: 'Failed to retrieve audio in TTS Process ', index printString, ' error: ', each error printString.

					"Remove this entry"
					removeFrom := removeTo := index ]
				ifFalse: [
					each ifNotNil: [
						"Store result (it is a valid result)"
						result := each.
						
						"Remove all entries (we are done)"
						removeFrom := 1.
						removeTo := processes size ] ].

			"Remove Process, client and result (if so requested)"
			removeFrom to: removeTo do: [ :removeIndex |
				(clients at: removeIndex) ifNotNil: [ :localClient |
					localClient close.
					clients at: removeIndex put: nil ].
				(processes at: removeIndex) ifNotNil: [ :process |
					(process isTerminating or: [ process isTerminated ])
						ifFalse: [ process terminate ].
					processes at: removeIndex put: nil ].
				results at: removeIndex put: nil ] ] ].

	"Answer final result or an empty Array if no result is retrieved"
	^ result ifNil: [ #() ]
]

{ #category : 'public' }
OpenAISDK >> createChatCompletionWithMessages: aChatObjectsArray model: aModelString temperature: aTemperatureFloat [

	| dict theClient json response decoded |
	dict := {
		        ('messages'
		         -> (aChatObjectsArray collect: [ :e | e toDictionary ])).
		        ('model' -> aModelString).
		        ('temperature' -> aTemperatureFloat) } asDictionary.
	self responseJson ifTrue: [
		dict at: 'response_format' put: { ('type' -> 'json_object') } asDictionary ].
	json := NeoJSONWriter toString: dict.

	theClient := self client.
	theClient 
		entity: (ZnEntity with: json type: ZnMimeType applicationJson);
		url: self baseURL , '/chat/completions'.

	response := theClient "logToTranscript; logLevel: 3;"  post.

	decoded := NeoJSONReader fromString: response.
	(decoded includesKey: 'error') ifTrue: [
		OpenAISDKException signalForObject: decoded ].

	^ OpenAISDKChatCompletion createWithAPIResponse: decoded
]

{ #category : 'public' }
OpenAISDK >> createChatCompletionWithMessagesAsStream: aChatObjectsArray model: aModelString temperature: aTemperatureFloat topP: aTopPValue presencePenalty: aPresencePenalty freqquencePenalty: aFrequencePenalty onStream: aStream [

	| dict myclient jsonData stream partialData |

	dict := {
		'messages' -> (aChatObjectsArray collect: [ :e | e toDictionary ]).
		'model' -> aModelString.
		'temperature' -> aTemperatureFloat.
		'top_p' -> aTopPValue asNumber.
		'presence_penalty' -> aPresencePenalty asNumber.
		'frequency_penalty' -> aFrequencePenalty asNumber.
		'stream' -> true.
		'stream_options' -> { 'include_obfuscation' -> false } asDictionary } asDictionary.
	jsonData := NeoJSONWriter toString: dict.

	myclient := self client.
	myclient
		url: self baseURL , '/chat/completions';
		entity: (ZnEntity json: jsonData);
		method: 'POST';
		streaming: true.

	"Send the request and process the streaming response"
	stream := myclient execute ifNil: [
		self errorCr: 'OpenAI: Executing streaming /chat/completions failed'.
		^ self ].

	"Retrieve data in chunks.
	Since any data record can also be split in chunks, ensure we read a full record before processing it."
	partialData := OrderedCollection new: 100.

	"Process the result until either no data is left or the marker 'stopped' is found"
	[ stream atEnd  or: [ aStream isStopped ] ] whileFalse: [
		| chunk lines |

		"Read in chunk and perform UTF-8 decoding"
		chunk := ByteArray new: stream limit.
		stream next: stream limit into: chunk.
		chunk := chunk utf8Decoded trimIfRequired.

		"Add the chunk, which can consist of multiple lines, to the existing partial data.
		Remove separators from the chunk and ignore any empty lines.
		Then either add a new record or append to the last (partial) record."
		lines := (chunk lines collect: [ :each | each trimIfRequired ])
			reject: [ :each | each isEmpty ].
		lines do: [ :each |
			partialData add: ((each beginsWith: 'data: ')
				ifTrue: [ each ]
				ifFalse: [ partialData removeLast, each ]) ].

		"Process full records from the partial data (should be all except possibly the last one)"
		partialData do: [ :each |
			((each beginsWith: 'data: {') and: [ each endsWith: '}' ])
				ifTrue: [
					| jsonRecord |
					jsonRecord := NeoJSONReader fromString: (each allButFirst: 5).	"Extract JSON without the 'data:' part"
					(((jsonRecord at: #choices) first at: #finish_reason) = 'stop')
						ifTrue: [
							"Mark the assistent 'stopped'"
							aStream nextPut: (OpenAISDKChat createWithRole: 'assistant_stop' content: '') ]
						ifFalse: [
							"Extract the text and add to chat"
							(((jsonRecord at: #choices) first at: #delta) at: #content) ifNotNil: [ :text |
								aStream nextPut: (OpenAISDKChat createWithRole: 'assistant' content: text) ] ] ] ].

		partialData ifNotEmpty: [
			partialData last ifNotNil: [ :last |
				| isPartial |
				isPartial := (last endsWith: '}') not.

				"Keep only the last if it is partial"
				partialData removeAll.
				isPartial
					ifTrue: [ partialData add: last ] ] ] ].

	stream close
]

{ #category : 'public' }
OpenAISDK >> createImageWithPrompt: aPromptString [

	^ self createImageWithPrompt: aPromptString number: 1 size: '1024x1024'
]

{ #category : 'public' }
OpenAISDK >> createImageWithPrompt: aPromptString number: aNumberString size: aSizeString [
	"https://platform.openai.com/docs/api-reference/images/create"

	| dict theClient json response decoded |
	dict := {
		        ('prompt' -> aPromptString).
		        ('n' -> aNumberString).
		        ('size' -> aSizeString) } asDictionary.
	json := NeoJSONWriter toString: dict.

	theClient := self client.
	theClient
		entity: (ZnEntity with: json type: ZnMimeType applicationJson);
		url: self baseURL , '/images/generations'.

	response := theClient post.

	decoded := NeoJSONReader fromString: response.
	(decoded includesKey: 'error') ifTrue: [
		OpenAISDKException signalForObject: decoded ].

	^ OpenAISDKImage createWithAPIResponse: decoded
]

{ #category : 'private' }
OpenAISDK >> createStreamingAudioClientOn: jsonString [

	"Answer a new ZnClient based on the global ZnClient which is stored in the receiver.
	Use the headers from this global client to set the headers of the new client.
	Run the client in streaming mode to allow early recognition of some data coming in.
	Limit the timeout from default 60s to 30s to prevent too long delays.
	Do NOT perform any retries. Retries are handled differently."

	| headers |

	headers := self client request headers.

	^ ZnClient new
		headerAt: 'Content-Type' put: (headers at: 'Content-Type') ;
		headerAt: 'Authorization' put: (headers at: 'Authorization') ;
		url: self baseURL , '/audio/speech' ;
		timeout: 30 ;
		numberOfRetries: 0;
		streaming: true ;
		entity: (ZnEntity with: jsonString type: ZnMimeType applicationJson) ;
		method: 'POST' ;
		yourself
]

{ #category : 'public' }
OpenAISDK >> createTranscriptFromBinary: byteArray model: aModelString [

	| theClient response znMulti |

	znMulti := ZnMultiPartFormDataEntity new.
	znMulti addPart: (ZnMimePart fieldName: 'model' value: aModelString).
	znMulti addPart: (ZnMimePart fieldName: 'file' fileName:'afile.wav' entity: (ZnByteArrayEntity bytes: byteArray) ).

	theClient := self client.
	theClient
		entity: znMulti ;
		url: self baseURL , '/audio/transcriptions'.

	response := theClient post.
	^ response
]

{ #category : 'public' }
OpenAISDK >> listModelIds [

	"Answer a collection of model identifiers"

	"https://platform.openai.com/docs/api-reference/models/list"

	^ self listModels data
		collect: [ :e | e id ]
]

{ #category : 'public' }
OpenAISDK >> listModels [
	"https://platform.openai.com/docs/api-reference/models/list"

	| theClient response decoded |
	theClient := self client.
	theClient url: self baseURL , '/models'.

	response := theClient get.

	decoded := NeoJSONReader fromString: response.
	(decoded includesKey: 'error') ifTrue: [
		OpenAISDKException signalForObject: decoded ].

	^ OpenAISDKModels createWithAPIResponse: decoded
]

{ #category : 'accessing' }
OpenAISDK >> responseJson [

	^ responseJson ifNil: [ false ]
]

{ #category : 'accessing' }
OpenAISDK >> responseJson: aBoolean [

	responseJson := aBoolean
]

{ #category : 'public' }
OpenAISDK >> retrieveModel: aModelString [
	"https://platform.openai.com/docs/api-reference/models/retrieve"

	| theClient response decoded |
	theClient := self client.
	theClient url: self baseURL , '/models/' , aModelString.

	response := theClient get.

	decoded := NeoJSONReader fromString: response.
	(decoded includesKey: 'error') ifTrue: [
		OpenAISDKException signalForObject: decoded ].

	^ OpenAISDKModel createWithAPIResponse: decoded
]
