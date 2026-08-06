"
Class: OpenAIChatSession

I represent a chat session with the OpenAI API.

Responsibilities:
- I initialize a chat session with the given OpenAI SDK.
- I set the model and temperature for the chat session.
- I manage the chat session's configuration and state.

Collaborators:
- OpenAISDK: I use the provided OpenAISDK instance to interact with the OpenAI API.
- Model: I use the specified model (e.g., 'gpt-3.5-turbo') for generating chat responses.
- Temperature: I use the specified temperature (e.g., 1.0) to control the randomness of the chat responses.

Example:
- ""Create a new OpenAIChatSession with a specific model and temperature: `OpenAIChatSession startWithSDK: myOpenAISDK model: 'gpt-3.5-turbo' temperature: 0.8`""


[This comment was automatically created with https://github.com/brackendev/OpenAI-Pharo]
"
Class {
	#name : 'OpenAIChatSession',
	#superclass : 'Object',
	#instVars : [
		'sdk',
		'chats',
		'model',
		'temperature',
		'topP',
		'presencePenalty',
		'frequencyPenalty',
		'functions',
		'functionCallHandler'
	],
	#category : 'OpenAI-Core',
	#package : 'OpenAI',
	#tag : 'Core'
}

{ #category : 'instance creation' }
OpenAIChatSession class >> startWithSDK: anOpenAISDK [

	^ self
		  startWithSDK: anOpenAISDK
		  model: nil
		  temperature: nil
		  topP: nil
		  presencePenalty: nil
		  frequencyPenalty: nil
]

{ #category : 'instance creation' }
OpenAIChatSession class >> startWithSDK: anOpenAISDK model: aModelString temperature: aTemperatureFloat topP: anObject presencePenalty: aPresencePenalty frequencyPenalty: aFrequencePenalty [

	| c |
	c := self new sdk: anOpenAISDK.
	aModelString
		ifNil: [ c model: 'gpt-3.5-turbo' ]
		ifNotNil: [ c model: aModelString ].
	aTemperatureFloat
		ifNil: [ c temperature: 1.0 ]
		ifNotNil: [ c temperature: aTemperatureFloat ].
	anObject ifNil: [ c topP: 0.8 ]
				ifNotNil: [ c topP: anObject ].
	aPresencePenalty ifNil: [ c presencePenalty: 0 ]
				ifNotNil: [ c presencePenalty: aPresencePenalty ].
	aFrequencePenalty ifNil: [ c frequencyPenalty: 0 ]
				ifNotNil: [ c frequencyPenalty: aFrequencePenalty ].

	^ c
]

{ #category : 'adding' }
OpenAIChatSession >> addChat: aChatObject [

	chats add: aChatObject
]

{ #category : 'adding' }
OpenAIChatSession >> addFunction: anOpenAISDKFunction [

	self functions add: anOpenAISDKFunction
]

{ #category : 'accessing' }
OpenAIChatSession >> chats [

	^ chats
]

{ #category : 'accessing' }
OpenAIChatSession >> chats: anObject [

	chats := anObject
]

{ #category : 'accessing' }
OpenAIChatSession >> frequencyPenalty [

	^ frequencyPenalty
]

{ #category : 'accessing' }
OpenAIChatSession >> frequencyPenalty: anObject [

	frequencyPenalty := anObject
]

{ #category : 'accessing' }
OpenAIChatSession >> functionCallHandler [

	^ functionCallHandler
]

{ #category : 'accessing' }
OpenAIChatSession >> functionCallHandler: aBlock [

	functionCallHandler := aBlock
]

{ #category : 'accessing' }
OpenAIChatSession >> functions [

	^ functions ifNil: [ functions := OrderedCollection new ]
]

{ #category : 'accessing' }
OpenAIChatSession >> functions: aCollection [

	functions := aCollection asOrderedCollection
]

{ #category : 'private' }
OpenAIChatSession >> handleFunctionCalls: aCollection [

	aCollection ifEmpty: [ ^ self ].
	functionCallHandler ifNil: [
		self error: 'OpenAI returned a function call, but no functionCallHandler is configured' ].
	aCollection do: [ :each |
		functionCallHandler value: each name value: each arguments ]
]

{ #category : 'initialization' }
OpenAIChatSession >> initialize [

	super initialize.
	chats := OrderedCollection new.
	functions := OrderedCollection new
]

{ #category : 'accessing' }
OpenAIChatSession >> lastChat [

	^ self chats last
]

{ #category : 'accessing' }
OpenAIChatSession >> model [

	^ model
]

{ #category : 'accessing' }
OpenAIChatSession >> model: anObject [

	model := anObject
]

{ #category : 'accessing' }
OpenAIChatSession >> presencePenalty [

	^ presencePenalty
]

{ #category : 'accessing' }
OpenAIChatSession >> presencePenalty: anObject [

	presencePenalty := anObject
]

{ #category : 'accessing' }
OpenAIChatSession >> sdk [

	^ sdk
]

{ #category : 'accessing' }
OpenAIChatSession >> sdk: anObject [

	sdk := anObject
]

{ #category : 'adding' }
OpenAIChatSession >> submitPrompt: aPromptString role: aRoleString [

	| chat response assistantChat |
	chat := OpenAISDKChat
		        createWithRole: aRoleString
		        content: aPromptString.
	self addChat: chat.

	response := sdk
		            createChatCompletionWithMessages: chats
		            model: model
		            temperature: temperature.

	assistantChat := response choices first message.
	self addChat: assistantChat
]

{ #category : 'adding' }
OpenAIChatSession >> submitPrompt: aPromptString role: aRoleString outputStream: aStream [

	| chat functionCalls |
	chat := OpenAISDKChat
		createWithRole: aRoleString
		content: aPromptString.
	self addChat: chat.

	functionCalls := self functions
		ifEmpty: [
			sdk
				createChatCompletionWithMessagesAsStream: chats
				model: model
				temperature: temperature
				topP: topP
				presencePenalty: presencePenalty
				freqquencePenalty: frequencyPenalty
				onStream: aStream.
			#() ]
		ifNotEmpty: [
			sdk
				createChatCompletionWithMessagesAsStream: chats
				model: model
				temperature: temperature
				topP: topP
				presencePenalty: presencePenalty
				freqquencePenalty: frequencyPenalty
				tools: self functions
				onStream: aStream ].

	self handleFunctionCalls: functionCalls.
	functionCalls ifNotEmpty: [
		aStream ifNotNil: [
			aStream nextPut: (OpenAISDKChat
				createWithRole: 'assistant_stop'
				content: '') ] ]
]

{ #category : 'adding' }
OpenAIChatSession >> submitPrompt: aPromptString roleResponses: aRoleString [

	| chat response assistantChat |
	chat := OpenAISDKChat
		createWithRole: aRoleString
		content: aPromptString.
	self addChat: chat.

	response := sdk
		createResponseWithMessages: chats
		model: model
		temperature: temperature.

	assistantChat := response firstAssistantChat.
	assistantChat ifNotNil: [
		self addChat: assistantChat ].
	^ assistantChat
]

{ #category : 'adding' }
OpenAIChatSession >> submitPrompt: aPromptString roleResponses: aRoleString outputStream: aStream [

	| chat |
	chat := OpenAISDKChat
		        createWithRole: aRoleString
		        content: aPromptString.
	self addChat: chat.

	sdk
		createResponseWithMessagesAsStream: chats
		model: model
		temperature: temperature
		topP: topP
		presencePenalty: presencePenalty
		frequencyPenalty: frequencyPenalty
		onStream: aStream
]

{ #category : 'adding' }
OpenAIChatSession >> submitPromptGpt5: aPromptString role: aRoleString [

	| chat response assistantChat |
	chat := OpenAISDKChat
		        createWithRole: aRoleString
		        content: aPromptString.
	self addChat: chat.

	response := sdk
		            createChatCompletionGpt5WithMessages: chats
		            model: model.

	assistantChat := response choices first message.
	self addChat: assistantChat
]

{ #category : 'adding' }
OpenAIChatSession >> submitSystemPrompt: aPromptString [

	self submitPrompt: aPromptString role: 'system'
]

{ #category : 'adding' }
OpenAIChatSession >> submitSystemPrompt: aPromptString outputStream: aStream [

	self submitPrompt: aPromptString role: 'system' outputStream: aStream.
]

{ #category : 'adding' }
OpenAIChatSession >> submitSystemPromptResponses: aPromptString [

	^ self submitPrompt: aPromptString roleResponses: 'system'
]

{ #category : 'adding' }
OpenAIChatSession >> submitSystemPromptResponses: aPromptString outputStream: aStream [

	self submitPrompt: aPromptString roleResponses: 'system' outputStream: aStream
]

{ #category : 'adding' }
OpenAIChatSession >> submitUserPrompt: aPromptString [

	self submitPrompt: aPromptString role: 'user'
]

{ #category : 'adding' }
OpenAIChatSession >> submitUserPrompt: aPromptString outputStream: aStream [

	self submitPrompt: aPromptString role: 'user' outputStream: aStream.
]

{ #category : 'adding' }
OpenAIChatSession >> submitUserPromptResponses: aPromptString [

	^ self submitPrompt: aPromptString roleResponses: 'user'
]

{ #category : 'adding' }
OpenAIChatSession >> submitUserPromptResponses: aPromptString outputStream: aStream [

	self
		submitPrompt: aPromptString
		roleResponses: 'user'
		outputStream: aStream
]

{ #category : 'accessing' }
OpenAIChatSession >> temperature [

	^ temperature 
]

{ #category : 'accessing' }
OpenAIChatSession >> temperature: anObject [

	temperature := anObject
]

{ #category : 'accessing' }
OpenAIChatSession >> topP [

	^ topP
]

{ #category : 'accessing' }
OpenAIChatSession >> topP: anObject [

	topP := anObject
]
