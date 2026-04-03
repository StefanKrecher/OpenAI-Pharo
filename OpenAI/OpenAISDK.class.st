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

	| dict theClient json response |
	dict := {
		        ('input'
		         -> anInputString ).
		        ('model' -> aModelString).
		        ('voice' -> aVoiceString ) } asDictionary.
	json := NeoJSONWriter toString: dict.

	theClient := self client.
	theClient
		entity: (ZnEntity with: json type: ZnMimeType applicationJson);
		url: self baseURL , '/audio/speech'.

	response := theClient post.
^response

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

	| dict myclient jsonData stream listOfChunks partialData |

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

	listOfChunks := OrderedCollection new.

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

				"Copy all but the partial"
				listOfChunks addAll: (isPartial
					ifTrue: [ partialData allButLast ]
					ifFalse: [ partialData ]).

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

{ #category : 'public' }
OpenAISDK >> createResponseWithMessages: aChatObjectsArray model: aModelString temperature: aTemperatureFloat [

	| dict json response decoded theClient |
	dict := self
		responseRequestDictionaryWithMessages: aChatObjectsArray
		model: aModelString
		temperature: aTemperatureFloat
		topP: nil
		presencePenalty: nil
		frequencyPenalty: nil
		stream: false.
	json := NeoJSONWriter toString: dict.

	theClient := self client.
	theClient
		entity: (ZnEntity with: json type: ZnMimeType applicationJson);
		url: self baseURL , '/responses'.

	response := theClient post.
	decoded := NeoJSONReader fromString: response.
	(decoded includesKey: 'error') ifTrue: [
		OpenAISDKException signalForObject: decoded ].

	^ OpenAISDKResponse createWithAPIResponse: decoded
]

{ #category : 'public' }
OpenAISDK >> createResponseWithMessagesAsStream: aChatObjectsArray model: aModelString temperature: aTemperatureFloat topP: aTopPValue presencePenalty: aPresencePenalty frequencyPenalty: aFrequencyPenalty onStream: aStream [

	| dict jsonData clientStream myclient partialData |
	dict := self
		        responseRequestDictionaryWithMessages: aChatObjectsArray
		        model: aModelString
		        temperature: aTemperatureFloat
		        topP: aTopPValue
		        presencePenalty: aPresencePenalty
		        frequencyPenalty: aFrequencyPenalty
		        stream: true.
	jsonData := NeoJSONWriter toString: dict.

	myclient := self client.
	myclient
		url: self baseURL , '/responses';
		entity: (ZnEntity json: jsonData);
		method: 'POST';
		streaming: true.

	clientStream := myclient execute ifNil: [
			                self errorCr:
				                'OpenAI: Executing streaming /responses failed'.
			                ^ self ].

	partialData := String new writeStream.
	[ clientStream atEnd or: [ aStream isStopped ] ] whileFalse: [
			| chunk |
			chunk := clientStream upToEnd.
			"clientStream next: clientStream limit into: chunk."
			partialData nextPutAll: chunk utf8Decoded.
			self flushResponseStreamBuffer: partialData on: aStream ].

	self flushResponseStreamBuffer: partialData on: aStream.
	clientStream close
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

{ #category : 'private' }
OpenAISDK >> flushResponseStreamBuffer: aWriteStream on: anOutputStream [

	| buffer records trailing |
	buffer := aWriteStream contents.
	(buffer includesSubstring: String lf , String lf) ifFalse: [
		^ self ].
	records := buffer findTokens: String crlf , String crlf.
	trailing := (buffer endsWith: String crlf , String crlf)
		            ifTrue: [ '' ]
		            ifFalse: [ records removeLast ].
	aWriteStream reset.
	aWriteStream nextPutAll: trailing.
	records do: [ :each |
		self processResponseStreamRecord: each on: anOutputStream ]
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

{ #category : 'private' }
OpenAISDK >> processResponseStreamRecord: aRecordString on: anOutputStream [

	| lines eventName dataLines jsonRecord |
	lines := (aRecordString lines collect: [ :each | each trimBoth ])
		         reject: [ :each | each isEmpty ].
	lines ifEmpty: [ ^ self ].
	eventName := nil.
	dataLines := OrderedCollection new.
	lines do: [ :each |
			(each beginsWith: 'event: ')
				ifTrue: [ eventName := each allButFirst: 7 ]
				ifFalse: [
						(each beginsWith: 'data: ') ifTrue: [
							dataLines add: (each allButFirst: 6) ] ] ].
	dataLines ifEmpty: [ ^ self ].
	(dataLines size = 1 and: [ dataLines first = '[DONE]' ]) ifTrue: [
		^ self ].
	jsonRecord := NeoJSONReader fromString:
		              (String streamContents: [ :stream |
			               dataLines do: [ :each | stream nextPutAll: each ] ]).
	jsonRecord at: 'type' ifAbsentPut: [ eventName ].
	anOutputStream nextPut:
		(OpenAISDKResponseStreamEvent createWithAPIResponse: jsonRecord)
]

{ #category : 'private' }
OpenAISDK >> responseEventFromJson: aDictionary defaultType: anEventName [

	aDictionary at: 'type' ifAbsentPut: [ anEventName ].
	^ OpenAISDKResponseStreamEvent createWithAPIResponse: aDictionary
]

{ #category : 'private' }
OpenAISDK >> responseInputItemFromChat: aChatObject [

	^ {
		  ('type' -> 'message').
		  ('role' -> aChatObject role).
		  ('content' -> (aChatObject role = 'assistant'
			    ifTrue: [
					    { {
						    ('type' -> 'output_text').
						    ('text' -> aChatObject content) } asDictionary } ]
			    ifFalse: [
					    {
						    {
							    ('type' -> 'input_file').
							    ('file_id' -> 'file-7Emaz1zh1TEW1L4f1a7D33') "FIXE FILE_ID" } asDictionary.
						    {
							    ('type' -> 'input_text').
							    ('text' -> aChatObject content) } asDictionary } ])) }
		  asDictionary
]

{ #category : 'private' }
OpenAISDK >> responseInputItemsFromMessages: aChatObjectsArray [

	| messages inputItems |
	messages := aChatObjectsArray asOrderedCollection.
	(messages notEmpty and: [ messages first role = 'system' ]) ifTrue: [
		messages := messages allButFirst ].
	inputItems := messages collect: [ :each |
		              self responseInputItemFromChat: each ].
	(inputItems isEmpty and: [ aChatObjectsArray notEmpty ]) ifTrue: [
			inputItems := OrderedCollection with:
				              (self responseInputItemFromChat:
					               aChatObjectsArray first) ].
	^ inputItems
]

{ #category : 'private' }
OpenAISDK >> responseInstructionsFromMessages: aChatObjectsArray [

	aChatObjectsArray ifEmpty: [ ^ nil ].
	^ aChatObjectsArray first role = 'system'
		ifTrue: [ aChatObjectsArray first content ]
		ifFalse: [ nil ]
]

{ #category : 'accessing' }
OpenAISDK >> responseJson [

	^ responseJson ifNil: [ false ]
]

{ #category : 'accessing' }
OpenAISDK >> responseJson: aBoolean [

	responseJson := aBoolean
]

{ #category : 'private' }
OpenAISDK >> responseRequestDictionaryWithMessages: aChatObjectsArray model: aModelString temperature: aTemperatureFloat topP: aTopPValue presencePenalty: aPresencePenalty frequencyPenalty: aFrequencyPenalty stream: aBoolean [

	| dict instructions |
	dict := OrderedDictionary new.
	instructions := self responseInstructionsFromMessages: aChatObjectsArray.
	instructions ifNotNil: [
		dict at: 'instructions' put: instructions ].
	dict
		at: 'input' put: (self responseInputItemsFromMessages: aChatObjectsArray);
		at: 'model' put: aModelString;
		at: 'temperature' put: aTemperatureFloat.
	aTopPValue ifNotNil: [
		dict at: 'top_p' put: aTopPValue asNumber ].
	aPresencePenalty ifNotNil: [
		dict at: 'presence_penalty' put: aPresencePenalty asNumber ].
	aFrequencyPenalty ifNotNil: [
		dict at: 'frequency_penalty' put: aFrequencyPenalty asNumber ].
	aBoolean ifTrue: [
		dict at: 'stream' put: true ].
	self responseJson ifTrue: [
		dict at: 'text' put: { ('format' -> { ('type' -> 'json_object') } asDictionary) } asDictionary ].
	^ dict
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
