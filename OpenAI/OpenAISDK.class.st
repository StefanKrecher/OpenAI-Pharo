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
		'client'
	],
	#category : 'OpenAI-Core',
	#package : 'OpenAI',
	#tag : 'Core'
}

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
	json := NeoJSONWriter toString: dict.

	theClient := self client.
	theClient 
		entity: (ZnEntity with: json type: ZnMimeType applicationJson);
		url: self baseURL , '/chat/completions'.

	response := theClient logToTranscript; logLevel: 3;  post.

	decoded := NeoJSONReader fromString: response.
	(decoded includesKey: 'error') ifTrue: [
		OpenAISDKException signalForObject: decoded ].

	^ OpenAISDKChatCompletion createWithAPIResponse: decoded
]

{ #category : 'public' }
OpenAISDK >> createChatCompletionWithMessagesAsStream: aChatObjectsArray model: aModelString temperature: aTemperatureFloat onStream: aStream [

	| dict myclient jsonData stream listOfChunks chunkObjects |
	dict := {
		        ('messages'
		         -> (aChatObjectsArray collect: [ :e | e toDictionary ])).
		        ('model' -> aModelString).
		        ('temperature' -> aTemperatureFloat).
		        ('stream' -> 'true') } asDictionary.
	jsonData := NeoJSONWriter toString: dict.

	listOfChunks := OrderedCollection new.
	chunkObjects := OrderedCollection new.

	myclient := self client.
	myclient
		url: self baseURL , '/chat/completions';
		entity: (ZnStringEntity with: jsonData type: ZnMimeType applicationJson).


	"Send the request and process the streaming response"
	stream := myclient execute.

	stream
		ifNotNil: [
			[ stream atEnd ] whileFalse: [
				| oc completionChunkObjectsAsText |
				oc := OrderedCollection new: stream limit withAll: nil.
				stream readInto: oc startingAt: 1 count: stream limit.

				completionChunkObjectsAsText := oc asByteArray asString lines
					                                reject: [ :each |
					                                each isEmpty or: [
						                                each beginsWith: 'data: [DONE]' ] ].
				completionChunkObjectsAsText do: [ :o |
					| content json text |
					o isEmptyOrNil ifFalse: [
						content := '' join: {
								           ${.
								           (o asString copyAfter: ${) }.
						[
						json := NeoJSONReader fromString: content.
						((json at: #choices) first at: #finish_reason) = 'stop'
							ifFalse: [
								text := ((json at: #choices) first at: #delta) at: #content.
								aStream nextPut: text.
								Transcript show: text ] ]
							on: Error
							do: [ :ex | Transcript show: ex ] ] ].
				listOfChunks addAll: completionChunkObjectsAsText ].
			stream close ]
		ifNil: [
			Transcript
				show: 'Request failed with status ';
				cr ]
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
		url: self baseURL , '/audio/transcriptions'.

	response := theClient post.
	^ response

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
