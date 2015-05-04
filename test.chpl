config const capacity = 4;
config const P = 2;
config const C = 3;
config const N = 10;
config const BufferSize = 5;

var DEBUG_consumedData : sync real = 0;

const TERM = -1.0;

class BoundedBuffer {

    var buff$: [0..#BufferSize] sync real;
    var pSync$: [0..#BufferSize] sync bool;
    var cSync$: [0..#BufferSize] sync bool;

    var head = 0;
    var tail = 0;

    var all_done : bool = false;

    var pLock : sync bool;
    var cLock : sync bool;

    proc BoundedBuffer() {
    }

    proc produce( item: real ) : void {
    	 var my_index : int  = 0;

    	 pLock = true; // start lock
	 my_index = head;
	 head = (head + 1) % BufferSize;
	 var unlock = pLock; // release lock

	 // sync object to prevent multiple writers from
	 // writing at the same index.
	 pSync$[my_index] = true;
	 buff$[my_index] = item;
	 unlock = pSync$[my_index];
    }

    proc consume( ) : real {
    	 var item : real = 0;
    	 var my_index  = 0;

    	 cLock = true; // start lock
	 my_index = tail;
	 tail = (tail + 1) % BufferSize;
	 var unlock = cLock; // release lock

	 // sync object to prevent multiple readers from
	 // reading the same index.
	 cSync$[my_index] = true;
	 if (all_done) {
	    item = TERM;
	 } else {
	    item = buff$[my_index];
	 }
	 unlock = cSync$[my_index];

	 return item;
    }

    proc done() : void {
    	 // set done to true to prevent all potential new
	 // reader from waiting.
    	 all_done = true;
	 // release all readers already waiting (if any).
	 while (head != tail) {
	       buff$[head] = TERM;
	       head = (head + 1) % BufferSize;
	 }
    }
}

// consumer task procedure
proc consumer(b: BoundedBuffer, id: int) {
    // keep consuming until it gets a TERM element
    var count = 0;
    do {
        writeln(id, " consuming ");
        const data = b.consume();
        writeln(id, " consumed ", data);
	
	if (data != TERM) {
	   DEBUG_consumedData += data;
	}

        count += 1;
    } while (data!=TERM);

    return count-1;
}

// producer task procedure
proc producer(b: BoundedBuffer, id: int) {
    // produce my strided share of N elements
    writeln("producer ", id, " in charge of ", 0..#N align id);
    var count = 0;
    for i in 0..#N by P align id {
        writeln(id, " producing ", i);
        b.produce(i);
        count += 1;
    }

    return count;
}

// produce an element that indicates that the consumer should exit
proc signalExit(b: BoundedBuffer) {
    b.produce(TERM);
}

var P_count: [0..#P] int;
var C_count: [0..#C] int;
var theBuffer = new BoundedBuffer();
cobegin {
    {
	// spawn P producers
	coforall prodID in 0..#P do
	P_count[prodID] = producer(theBuffer, prodID);

	// when producers are all done, produce C exit signals
        for consID in 0..#C do
	    signalExit(theBuffer);

	// let the buffer know we are done.
	theBuffer.done();
    }
   
    // spawn C consumers 
    coforall consID in 0..#C do
        C_count[consID] = consumer(theBuffer, consID);
}    
writeln("== TOTALS ==");
writeln("P_count=", P_count);
writeln("C_count=", C_count);
if (DEBUG_consumedData != (N-1)*N/2) {
   writeln("Not All values were consumed!");
}
