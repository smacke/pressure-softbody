2D Pressurized Soft Body Simulation
===================================

An implementation of Maciej Matyka's soft body
[tutorial paper](http://panoramix.ift.uni.wroc.pl/~maq/soft2d/howtosoftbody.pdf).

One of my main reasons for choosing to implement this in Java was the relative
ease with which I could demo it using a Java applet. With the development of
[more stringent security requirements for applets](http://www.oracle.com/technetwork/java/javase/tech/java-code-signing-1915323.html),
however, this is no longer the case (unless I shell out 100+ U.S.D. for the
ability to sign code using an X.509 certificate backed by a trusted cert authority).

As a result, I decided to port what I had to [Processing](https://processing.org/),
which was surprisingly painless. The [demo](http://smacke.net/pressure-softbody/)
uses [Processing.js](http://processingjs.org/).

Note: I wrote the original Java code in high school, which is the reason for the single source
file, default package, magic numbers, and generally awful code. I cleaned it up a little since then, but
not by much.  Still, it is nice in that it's self-contained for anybody looking
for a terrible example of Java multithreading to manually update AWT
components.


License
=======

Code is released under the FreeBSD / simplified BSD license.
