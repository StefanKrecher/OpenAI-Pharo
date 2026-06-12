Class {
	#name : 'OpenAIParallelClientError',
	#superclass : 'Object',
	#instVars : [
		'error'
	],
	#category : 'OpenAI-Core',
	#package : 'OpenAI',
	#tag : 'Core'
}

{ #category : 'instance creation' }
OpenAIParallelClientError class >> error: anObject [

	^ self basicNew
		initializeWithError: anObject ;
		yourself
]

{ #category : 'accessing' }
OpenAIParallelClientError >> error [

	^ error
]

{ #category : 'initialization' }
OpenAIParallelClientError >> initializeWithError: anObject [

	self initialize.

	error := anObject
]
