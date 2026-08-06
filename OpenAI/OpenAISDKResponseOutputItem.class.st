Class {
	#name : 'OpenAISDKResponseOutputItem',
	#superclass : 'Object',
	#instVars : [
		'rawItem'
	],
	#category : 'OpenAI',
	#package : 'OpenAI'
}

{ #category : 'instance creation' }
OpenAISDKResponseOutputItem class >> createWithAPIResponse: aResponseItemDictionary [

	^ self new
		rawItem: aResponseItemDictionary
]

{ #category : 'accessing' }
OpenAISDKResponseOutputItem >> content [

	^ self rawItem at: 'content' ifAbsent: [ #() ]
]

{ #category : 'accessing' }
OpenAISDKResponseOutputItem >> rawItem [

	^ rawItem
]

{ #category : 'accessing' }
OpenAISDKResponseOutputItem >> rawItem: aDictionary [

	rawItem := aDictionary
]

{ #category : 'accessing' }
OpenAISDKResponseOutputItem >> role [

	^ self rawItem at: 'role' ifAbsent: [ nil ]
]

{ #category : 'convenience' }
OpenAISDKResponseOutputItem >> text [

	^ String streamContents: [ :stream |
		self textParts do: [ :each |
			stream nextPutAll: each ] ]
]

{ #category : 'convenience' }
OpenAISDKResponseOutputItem >> textParts [

	^ self content
		select: [ :each |
			| type |
			type := each at: 'type' ifAbsent: [ '' ].
			(type = 'output_text') or: [ type = 'text' ] ]
		thenCollect: [ :each |
			each at: 'text' ifAbsent: [ '' ] ]
]

{ #category : 'accessing' }
OpenAISDKResponseOutputItem >> type [

	^ self rawItem at: 'type' ifAbsent: [ nil ]
]
