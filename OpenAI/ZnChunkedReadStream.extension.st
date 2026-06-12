Extension { #name : 'ZnChunkedReadStream' }

{ #category : '*OpenAI' }
ZnChunkedReadStream >> chunk [

	^ chunk
]

{ #category : '*OpenAI' }
ZnChunkedReadStream >> hasReceivedSomeData [

	"Answer whether some data is read"

	"Ensure some data is requested"
	self ensureChunkOrAtEnd.

	^ atEnd or: [ totalSize > 0 ]
]

{ #category : '*OpenAI' }
ZnChunkedReadStream >> limit [

	^ limit
]
