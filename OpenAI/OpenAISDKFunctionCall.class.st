Class {
	#name : 'OpenAISDKFunctionCall',
	#superclass : 'Object',
	#instVars : [
		'id',
		'index',
		'name',
		'rawArguments'
	],
	#category : 'OpenAI-Model',
	#package : 'OpenAI',
	#tag : 'Model'
}

{ #category : 'instance creation' }
OpenAISDKFunctionCall class >> id: anId index: anIndex name: aName rawArguments: anArgumentsString [

	^ self new
		id: anId;
		index: anIndex;
		name: aName;
		rawArguments: anArgumentsString;
		yourself
]

{ #category : 'building' }
OpenAISDKFunctionCall >> appendName: aString [

	aString ifNotNil: [
		name := self name , aString ]
]

{ #category : 'building' }
OpenAISDKFunctionCall >> appendRawArguments: aString [

	aString ifNotNil: [
		rawArguments := self rawArguments , aString ]
]

{ #category : 'accessing' }
OpenAISDKFunctionCall >> arguments [

	self rawArguments ifEmpty: [ ^ Dictionary new ].
	^ NeoJSONReader fromString: self rawArguments
]

{ #category : 'accessing' }
OpenAISDKFunctionCall >> id [

	^ id
]

{ #category : 'accessing' }
OpenAISDKFunctionCall >> id: aString [

	id := aString
]

{ #category : 'accessing' }
OpenAISDKFunctionCall >> index [

	^ index
]

{ #category : 'accessing' }
OpenAISDKFunctionCall >> index: anInteger [

	index := anInteger
]

{ #category : 'accessing' }
OpenAISDKFunctionCall >> name [

	^ name ifNil: [ '' ]
]

{ #category : 'accessing' }
OpenAISDKFunctionCall >> name: aString [

	name := aString
]

{ #category : 'accessing' }
OpenAISDKFunctionCall >> rawArguments [

	^ rawArguments ifNil: [ '' ]
]

{ #category : 'accessing' }
OpenAISDKFunctionCall >> rawArguments: aString [

	rawArguments := aString
]
