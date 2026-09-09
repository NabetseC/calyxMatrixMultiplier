I am going with the triple for loop since it keeps it simple. This lets me get acquainted with the language with more ease since the algo logic part isn’t heavy. 

I am beginning by writing one while-for loop. After that it’s just rinse and repeat. I am not sure about the matrix multiplication side yet, but I don’t want to waste time planning a lot. I am beginning with the easy stuff first, which should also help me define the “hard” stuff more easily since there’s more code to ground it in. 

Does to matter if increase is inside the par brackets or at the same level? In the tut it doesn’t. It did.

Had some small issues. Main technical one was that I had the increments outside the seq. In the tutorial it’s fine since the body doesn’t touch the counter, but here, incrementing I,j, or k parallel means we can increase the index prematurely. 

There’s a lot of overlap with c or other languages where you might do “for (int i = 0; ...)" . It’s the basics of a loop. But here, you have to be a lot more manual about writing the code.  

I spent some time learning more about statics. I was somewhat confused at why the cycles dropped so much from the inner K loop becoming repeat. I understood it would have a greater effect than the others, but I didn’t see how it decreased the number by so much. I used AI to review the code and look into the logs to see how this happened. It highlighted that most of the extra “gain” came from the avoiding handshakes between static and Dynamic Islands. 

I began with 1942 to do a 6x5 @ 5x7 matrix multiplication and ended with 1189 after optimizing using statics. I kept the algorithm as a simple triple nested loop throughout. 
