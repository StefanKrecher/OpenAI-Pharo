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
		'responseJson',
		'apiKeyString',
		'organization'
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

	^ self new
		apiKeyString: anAPIKeyString ;
		organization: anOrganizationString ;
		createClient ;
		yourself
]

{ #category : 'public' }
OpenAISDK class >> openUsagePage [

	WebBrowser openOn: 'https://platform.openai.com/account/usage'
]

{ #category : 'accessing' }
OpenAISDK >> apiKeyString [

	^ apiKeyString
]

{ #category : 'accessing' }
OpenAISDK >> apiKeyString: anObject [

	apiKeyString := anObject
]

{ #category : 'private' }
OpenAISDK >> assistantTextFromDelta: aDelta [

	| content |
	content := self
		jsonValueAtAnyKeyOf: aDelta
		keys: #(#content 'content' #text 'text')
		ifAbsent: [ nil ].
	content ifNil: [ ^ nil ].
	content isString ifTrue: [ ^ content ].
	(content isCollection and: [ content isString not ]) ifTrue: [
		^ String streamContents: [ :stream |
			content do: [ :each |
				| text |
				(each respondsTo: #at:ifAbsent:)
					ifTrue: [
						text := self
							jsonValueAtAnyKeyOf: each
							keys: #(#text 'text')
							ifAbsent: [ nil ].
						text ifNotNil: [ stream nextPutAll: text asString ] ]
					ifFalse: [ stream nextPutAll: each asString ] ] ] ].
	^ content asString
]

{ #category : 'private' }
OpenAISDK >> assistantTextFromResponse: aResponseDictionary [

	| directText output |
	directText := self
		jsonValueAtAnyKeyOf: aResponseDictionary
		keys: #(#output_text 'output_text')
		ifAbsent: [ nil ].
	directText ifNotNil: [ ^ directText asString ].
	output := self
		jsonValueAtAnyKeyOf: aResponseDictionary
		keys: #(#output 'output')
		ifAbsent: [ #() ].
	^ String streamContents: [ :stream |
		output do: [ :item |
			| type role content |
			type := self jsonValueAtAnyKeyOf: item keys: #(#type 'type') ifAbsent: [ nil ].
			role := self jsonValueAtAnyKeyOf: item keys: #(#role 'role') ifAbsent: [ nil ].
			((type = 'message') and: [ role = 'assistant' ]) ifTrue: [
				content := self jsonValueAtAnyKeyOf: item keys: #(#content 'content') ifAbsent: [ #() ].
				content do: [ :each |
					| itemType text |
					itemType := self jsonValueAtAnyKeyOf: each keys: #(#type 'type') ifAbsent: [ nil ].
					((itemType = 'output_text') or: [ itemType = 'text' ]) ifTrue: [
						text := self jsonValueAtAnyKeyOf: each keys: #(#text 'text') ifAbsent: [ nil ].
						text ifNotNil: [ stream nextPutAll: text asString ] ] ] ] ] ]
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
					('speed' -> 1).
		        ('voice' -> aVoiceString ) } asDictionary.
	json := NeoJSONWriter toString: dict.

	theClient := self client.
	theClient isConnected
		ifFalse: [
			self createClient.
			theClient := self client ].
	theClient
		method: #POST ;
		entity: (ZnEntity with: json type: ZnMimeType applicationJson);
		url: self baseURL , '/audio/speech'.
	response := theClient execute.
	Transcript show: 'Response for ', anInputString.
	theClient isSuccess
		ifFalse: [ 
			(Delay forSeconds: 2) wait.
			self createClient.
			^ self createAudioWithInput: anInputString model: aModelString voice: aVoiceString ].
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
OpenAISDK >> createChatCompletionWithMessagesAsStream: aChatObjectsArray model: aModelString temperature: aTemperatureFloat topP: aTopPValue onStream: aStream [

	| dict myclient jsonData stream |
	dict := {
		('messages' -> (aChatObjectsArray collect: [ :e | e toDictionary ])).
		('model' -> aModelString).
		('temperature' -> aTemperatureFloat).
		('top_p' -> aTopPValue asNumber).
		('stream' -> true) }
		asDictionary.
	jsonData := NeoJSONWriter toString: dict.

	myclient := self client.
	myclient
		url: self baseURL , '/chat/completions';
		entity: (ZnStringEntity with: jsonData type: ZnMimeType applicationJson);
		method: 'POST';
		streaming: true.

	stream := myclient execute.
	stream
		ifNotNil: [
			[ self streamChatCompletionResponse: stream onStream: aStream ]
				ensure: [ stream close ] ]
		ifNil: [ Transcript show: 'Request failed with status '; cr ]
]

{ #category : 'public' }
OpenAISDK >> createChatCompletionWithMessagesAsStream: aChatObjectsArray model: aModelString temperature: aTemperatureFloat topP: aTopPValue presencePenalty: aPresencePenalty freqquencePenalty: aFrequencePenalty onStream: aStream [

	| dict myclient jsonData stream |
	dict := {
		('messages' -> (aChatObjectsArray collect: [ :e | e toDictionary ])).
		('model' -> aModelString).
		('temperature' -> aTemperatureFloat).
		('top_p' -> aTopPValue asNumber).
		('presence_penalty' -> aPresencePenalty asNumber).
		('frequency_penalty' -> aFrequencePenalty asNumber).
		('stream' -> true) }
		asDictionary.
	jsonData := NeoJSONWriter toString: dict.

	myclient := self client.
	myclient
		url: self baseURL , '/chat/completions';
		entity: (ZnStringEntity with: jsonData type: ZnMimeType applicationJson);
		method: 'POST';
		streaming: true.

	[ stream := myclient execute ]
		on: Error
		do: [ :e | Transcript show: e printString; cr. ^ nil ].

	[ stream
		ifNotNil: [
			[ self streamChatCompletionResponse: stream onStream: aStream ]
				ensure: [ stream close ] ]
		ifNil: [ Transcript show: 'Request failed with status '; cr ] ]
		on: Error
		do: [ :ex | Transcript show: ex printString; cr ]
]

{ #category : 'as yet unclassified' }
OpenAISDK >> createClient [

	client := ZnClient new.
	client headerAt: 'Content-Type' put: 'application/json'.
	client headerAt: 'Authorization' put: 'Bearer ' , apiKeyString.
	organization isNotNil ifTrue: [ 
		client headerAt: 'OpenAI-Organization' put: organization ].
	client timeout: 60
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
OpenAISDK >> createResponseWithInput: anInputCollection instructions: anInstructionsString model: aModelString temperature: aTemperatureFloat topP: aTopPValue presencePenalty: aPresencePenalty frequencyPenalty: aFrequencyPenalty [

	| dict json response decoded theClient |
	dict := {
		        ('model' -> aModelString).
		        ('instructions' -> anInstructionsString).
		        ('input' -> anInputCollection).
		        ('temperature' -> aTemperatureFloat).
		        ('top_p' -> aTopPValue asNumber).
		        ('presence_penalty' -> aPresencePenalty asNumber).
		        ('frequency_penalty' -> aFrequencyPenalty asNumber) }
		        asDictionary.
	json := NeoJSONWriter toString: dict.

	theClient := self client.
	theClient
		entity: (ZnEntity with: json type: ZnMimeType applicationJson);
		url: self baseURL , '/responses'.

	response := theClient post.
	decoded := NeoJSONReader fromString: response.
	(decoded at: #error ifAbsent: [ ]) ifNotNil: [
		OpenAISDKException signalForObject: decoded ].
	^ decoded
]

{ #category : 'public' }
OpenAISDK >> createTranscriptFromBinary: byteArray model: aModelString [

	| dict theClient json response znMulti |
	dict := {
		        ('file' -> byteArray).
		        ('model' -> aModelString) } asDictionary.
	json := NeoJSONWriter toString: dict.

	znMulti := ZnMultiPartFormDataEntity new.
	znMulti addPart: (ZnMimePart fieldName: 'model' value: aModelString).
	znMulti addPart: (ZnMimePart fieldName: 'file' fileName:'afile.wav' entity: (ZnByteArrayEntity bytes: byteArray) ).

	theClient := self client.
	theClient
		entity: znMulti ;
		url: self baseURL , '/audio/transcriptions';
		headerAt: 'Connection' put: 'close'.

	response := theClient post.
	^ response

]

{ #category : 'private' }
OpenAISDK >> jsonValueAtAnyKeyOf: aDictionary keys: aCollection ifAbsent: aBlock [

	aCollection do: [ :each |
		(aDictionary includesKey: each) ifTrue: [ ^ aDictionary at: each ] ].
	^ aBlock value
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

{ #category : 'public' }
OpenAISDK >> listModelsAsText [
	"https://platform.openai.com/docs/api-reference/models/list"

	| theClient response decoded |
	theClient := self client.
	theClient url: self baseURL , '/models'.

	response := theClient get.

	decoded := NeoJSONReader fromString: response.
	^(decoded at: #data) collect: [ :entry | entry at: #id ]
]

{ #category : 'public' }
OpenAISDK >> listModelsDict [
	"https://platform.openai.com/docs/api-reference/models/list"

	| theClient response decoded |
	theClient := self client.
	theClient url: self baseURL , '/models'.

	response := theClient get.

	decoded := NeoJSONReader fromString: response.
	^ decoded 
]

{ #category : 'accessing' }
OpenAISDK >> organization [

	^ organization
]

{ #category : 'accessing' }
OpenAISDK >> organization: anObject [

	organization := anObject
]

{ #category : 'private' }
OpenAISDK >> processStreamingResponseLine: aLine onStream: aStream [

	| line payload json choices choice finishReason delta text |
	line := aLine ifNil: [ '' ] ifNotNil: [ aLine trimBoth ].
	line isEmpty ifTrue: [ ^ self ].
	(line beginsWith: 'data:') ifFalse: [ ^ self ].
	payload := (line copyAfter: $:) trimBoth.
	payload = '[DONE]' ifTrue: [ ^ self ].
	[ json := NeoJSONReader fromString: payload ]
		on: Error
		do: [ :ex |
				Transcript
					show: ex printString;
					cr.
				^ self ].
	choices := self
		           jsonValueAtAnyKeyOf: json
		           keys: #( #choices 'choices' )
		           ifAbsent: [ ^ self ].
	choices isEmpty ifTrue: [ ^ self ].
	choice := choices first.
	finishReason := self
		                jsonValueAtAnyKeyOf: choice
		                keys: #( #finish_reason 'finish_reason' )
		                ifAbsent: [ nil ].
	finishReason = 'stop' ifTrue: [
			aStream nextPut:
				(OpenAISDKChat createWithRole: 'assistant_stop' content: '').
			^ self ].
	delta := self
		         jsonValueAtAnyKeyOf: choice
		         keys: #( #delta 'delta' #message 'message' )
		         ifAbsent: [ Dictionary new ].
	text := self assistantTextFromDelta: delta.
	text ifNil: [ ^ self ].
	text isEmpty ifTrue: [ ^ self ].
	aStream nextPut:
		(OpenAISDKChat createWithRole: 'assistant' content: text)
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

{ #category : 'private' }
OpenAISDK >> streamChatCompletionResponse: aStreamingReadStream onStream: aStream [

	| pendingLine chunkText lines endedWithLineBreak |
	pendingLine := ''.
	[ aStreamingReadStream atEnd ] whileFalse: [
			chunkText := pendingLine
			             , (aStreamingReadStream next: 1024) asString.
			chunkText isEmpty ifFalse: [
					lines := chunkText lines asOrderedCollection.
					endedWithLineBreak := chunkText last = Character lf or: [
						                      chunkText last = Character cr ].
					endedWithLineBreak
						ifTrue: [ pendingLine := '' ]
						ifFalse: [
								pendingLine := lines isEmpty
									               ifTrue: [ '' ]
									               ifFalse: [ lines removeLast ] ].
					lines do: [ :each |
						self processStreamingResponseLine: each onStream: aStream ] ] ].
	pendingLine trimBoth ifNotEmpty: [
		self processStreamingResponseLine: pendingLine onStream: aStream ]
]
