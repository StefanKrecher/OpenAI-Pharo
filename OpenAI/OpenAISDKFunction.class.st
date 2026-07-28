Class {
	#name : 'OpenAISDKFunction',
	#superclass : 'Object',
	#instVars : [
		'name',
		'description',
		'parameters',
		'strict'
	],
	#category : 'OpenAI-Model',
	#package : 'OpenAI',
	#tag : 'Model'
}

{ #category : 'instance creation' }
OpenAISDKFunction class >> named: aName description: aDescription parameters: aDictionary [

	^ self new
		name: aName;
		description: aDescription;
		parameters: aDictionary;
		yourself
]

{ #category : 'serialization' }
OpenAISDKFunction >> asToolDictionary [

	| functionDictionary |
	functionDictionary := {
		'name' -> name.
		'description' -> description.
		'parameters' -> parameters } asDictionary.
	self strict ifTrue: [
		functionDictionary at: 'strict' put: true ].
	^ {
		'type' -> 'function'.
		'function' -> functionDictionary } asDictionary
]

{ #category : 'accessing' }
OpenAISDKFunction >> description [

	^ description
]

{ #category : 'accessing' }
OpenAISDKFunction >> description: aString [

	description := aString
]

{ #category : 'accessing' }
OpenAISDKFunction >> name [

	^ name
]

{ #category : 'accessing' }
OpenAISDKFunction >> name: aString [

	name := aString
]

{ #category : 'accessing' }
OpenAISDKFunction >> parameters [

	^ parameters
]

{ #category : 'accessing' }
OpenAISDKFunction >> parameters: aDictionary [

	parameters := aDictionary
]

{ #category : 'accessing' }
OpenAISDKFunction >> strict [

	^ strict ifNil: [ false ]
]

{ #category : 'accessing' }
OpenAISDKFunction >> strict: aBoolean [

	strict := aBoolean
]
