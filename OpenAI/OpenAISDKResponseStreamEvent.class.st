Class {
	#name : 'OpenAISDKResponseStreamEvent',
	#superclass : 'Object',
	#instVars : [
		'rawEvent'
	],
	#category : 'OpenAI',
	#package : 'OpenAI'
}

{ #category : 'instance creation' }
OpenAISDKResponseStreamEvent class >> createWithAPIResponse: anEventDictionary [

	^ self new
		rawEvent: anEventDictionary
]

{ #category : 'convenience' }
OpenAISDKResponseStreamEvent >> deltaText [

	^ self rawEvent
		at: 'delta'
		ifAbsent: [ self rawEvent at: 'text' ifAbsent: [ '' ] ]
]

{ #category : 'testing' }
OpenAISDKResponseStreamEvent >> isCompleted [

	^ self type = 'response.completed'
]

{ #category : 'testing' }
OpenAISDKResponseStreamEvent >> isError [

	^ (self type = 'error') or: [ self type = 'response.error' ]
]

{ #category : 'testing' }
OpenAISDKResponseStreamEvent >> isIncomplete [

	^ self type = 'response.incomplete'
]

{ #category : 'testing' }
OpenAISDKResponseStreamEvent >> isOutputTextDelta [

	^ self type = 'response.output_text.delta'
]

{ #category : 'accessing' }
OpenAISDKResponseStreamEvent >> rawEvent [

	^ rawEvent
]

{ #category : 'accessing' }
OpenAISDKResponseStreamEvent >> rawEvent: aDictionary [

	rawEvent := aDictionary
]

{ #category : 'accessing' }
OpenAISDKResponseStreamEvent >> type [

	^ self rawEvent at: 'type' ifAbsent: [ nil ]
]
