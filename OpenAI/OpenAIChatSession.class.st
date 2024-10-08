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
		'topP'
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
]

{ #category : 'instance creation' }
OpenAIChatSession class >> startWithSDK: anOpenAISDK model: aModelString temperature: aTemperatureFloat topP: anObject [

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
	^ c
]

{ #category : 'adding' }
OpenAIChatSession >> addChat: aChatObject [

	chats add: aChatObject
]

{ #category : 'accessing' }
OpenAIChatSession >> chats [

	^ chats
]

{ #category : 'accessing' }
OpenAIChatSession >> chats: anObject [

	chats := anObject
]

{ #category : 'initialization' }
OpenAIChatSession >> initialize [

	chats := OrderedCollection new
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

	| chat response assistantChat |
	chat := OpenAISDKChat
		        createWithRole: aRoleString
		        content: aPromptString.
	self addChat: chat.

	sdk createChatCompletionWithMessagesAsStream: chats
		            model: model
		            temperature: temperature
						topP: topP 
						onStream: aStream.

	"response := aStream contents.

	assistantChat := response choices first message.
	self addChat: assistantChat"
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
OpenAIChatSession >> submitUserPrompt: aPromptString [

	self submitPrompt: aPromptString role: 'user'
]

{ #category : 'adding' }
OpenAIChatSession >> submitUserPrompt: aPromptString outputStream: aStream [

	self submitPrompt: aPromptString role: 'user' outputStream: aStream.
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
