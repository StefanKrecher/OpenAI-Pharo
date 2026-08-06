Class {
	#name : 'OpenAISDKResponse',
	#superclass : 'Object',
	#instVars : [
		'id',
		'object',
		'createdAt',
		'model',
		'status',
		'output',
		'usage',
		'rawResponse'
	],
	#category : 'OpenAI',
	#package : 'OpenAI'
}

{ #category : 'instance creation' }
OpenAISDKResponse class >> createWithAPIResponse: aResponseDictionary [

	^ self new
		id: (aResponseDictionary at: 'id' ifAbsent: [ nil ]);
		object: (aResponseDictionary at: 'object' ifAbsent: [ nil ]);
		createdAt: (aResponseDictionary at: 'created_at' ifAbsent: [ nil ]);
		model: (aResponseDictionary at: 'model' ifAbsent: [ nil ]);
		status: (aResponseDictionary at: 'status' ifAbsent: [ nil ]);
		output: ((aResponseDictionary at: 'output' ifAbsent: [ #() ]) collect: [ :each |
			OpenAISDKResponseOutputItem createWithAPIResponse: each ]);
		usage: (aResponseDictionary at: 'usage' ifAbsent: [ nil ]);
		rawResponse: aResponseDictionary
]

{ #category : 'accessing' }
OpenAISDKResponse >> createdAt [

	^ createdAt
]

{ #category : 'accessing' }
OpenAISDKResponse >> createdAt: anInteger [

	createdAt := anInteger
]

{ #category : 'convenience' }
OpenAISDKResponse >> firstAssistantChat [

	| assistantText |
	assistantText := self firstAssistantText.
	assistantText ifEmpty: [ ^ nil ].
	^ OpenAISDKChat createWithRole: 'assistant' content: assistantText
]

{ #category : 'convenience' }
OpenAISDKResponse >> firstAssistantText [

	self output do: [ :each |
		each role = 'assistant' ifTrue: [
			each text ifNotEmpty: [ :text |
				^ text ] ] ].
	^ ''
]

{ #category : 'accessing' }
OpenAISDKResponse >> id [

	^ id
]

{ #category : 'accessing' }
OpenAISDKResponse >> id: aString [

	id := aString
]

{ #category : 'accessing' }
OpenAISDKResponse >> model [

	^ model
]

{ #category : 'accessing' }
OpenAISDKResponse >> model: aString [

	model := aString
]

{ #category : 'accessing' }
OpenAISDKResponse >> object [

	^ object
]

{ #category : 'accessing' }
OpenAISDKResponse >> object: aString [

	object := aString
]

{ #category : 'accessing' }
OpenAISDKResponse >> output [

	^ output ifNil: [ #() ]
]

{ #category : 'accessing' }
OpenAISDKResponse >> output: aCollection [

	output := aCollection
]

{ #category : 'convenience' }
OpenAISDKResponse >> outputText [

	^ String streamContents: [ :stream |
		self output do: [ :each |
			stream nextPutAll: each text ] ]
]

{ #category : 'accessing' }
OpenAISDKResponse >> rawResponse [

	^ rawResponse
]

{ #category : 'accessing' }
OpenAISDKResponse >> rawResponse: aDictionary [

	rawResponse := aDictionary
]

{ #category : 'accessing' }
OpenAISDKResponse >> status [

	^ status
]

{ #category : 'accessing' }
OpenAISDKResponse >> status: aString [

	status := aString
]

{ #category : 'accessing' }
OpenAISDKResponse >> usage [

	^ usage
]

{ #category : 'accessing' }
OpenAISDKResponse >> usage: aDictionary [

	usage := aDictionary
]
