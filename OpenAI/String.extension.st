Extension { #name : 'String' }

{ #category : '*OpenAI' }
String >> imageFromURL [

	^ ImageReadWriter formFromStream:
		  (ZnEasy get: self) contents readStream
]

{ #category : '*OpenAI' }
String >> outputTextFile: aFileNameString [

	(File named: aFileNameString) writeStreamDo: [ :stream | 
		stream nextPutAll: self ]
]

{ #category : '*OpenAI' }
String >> trimIfRequired [

	"Answer a trimmed copy of the receiver if trimming is required (i.e. separators are present).
	Otherwise answer the receiver (preventing a useless copy).

	Implementation:
	The ifEmpty clause is not needed, because #ifNotEmpty: will answer self for an empty receiver."

	^ self ifNotEmpty: [
		(self first isSeparator or: [ self last isSeparator ])
			ifTrue: [ self trim ]
			ifFalse: [ self ] ]
]
