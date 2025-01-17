#!/usr/bin/env bash

# Let's run IGV so we can see what Graal is doing
# IGV visualizes internal state of Graal
# You can get what you need to run it from https://github.com/oracle/graal and https://github.com/graalvm/mx
export PATH_TO_GRAAL_REPO=~/oracle/baseline/graal/
export PATH_TO_JDK_11=~/.mx/jdks/jdk-11.0.20/
(cd $PATH_TO_GRAAL_REPO/compiler && mx igv --jdkhome $PATH_TO_JDK_11 &)
sleep 10s

# Set GraalVM Home
export JAVA_HOME=$PWD/graalvm-jdk-21.0.2+13.1/
# Set path to maven
export MAVEN=~/apache-maven-3.9.6/bin/mvn

# Topic 1: Graal as a JIT for the JVM ========================================================================
# This diagram shows how the JVM executes a java file:
#
# .java -> javac -> .class -> | Interpreter ->  C1 -> jvmci -> Graal |
#                             |     ^           |               |    |
#                             |     |           V               V    |
#                             |     |       assembly        assembly |
#                             |     |           |               |    |
#                             |     +-----------+---------------+    |
#                             |______________________________________|
#                             |                JVM                   |
#
# TL;DR;
#   javac compiles Java code to JVM Bytecode (in class files)
#   JVM takes JVM Bytecode as input and starts interpreting it
#       While interpreting the JVM counts invocations (and profiles)
#   When a method is executed enough times in the intermediate, compile it with C1
#       C1 is a fast non-optimizing compiler that also profiles
#   When a method is executed enough times in C1, compile it with Graal
#       Graal takes the bytecode of the method and a profile
#       Graal is an *optimizing* compiler
#
# Graal uses the "Sea of nodes" IR
#   IR - Intermediate representation, how the compiler "sees" the code
#       Meant to be a format that it "easy" to manipulate
#       Code represented as a Graph with
#           Fixed nodes - things happen
#           Floating nodes - data happens
#       Phase based optimization - Each Graph Transformation is a "Phase"
#   Consider the second dump of GameOfLife.applyRules
#       If node id=33 after parsing does the same work as If node id=13
#       Graal figures it out and removes it eventually
# Speculative Optimizations
#   Profiles says X (e.g. this code was never executed) let's assume that's always true.
#   What if it's not true? Deoptimize (throw away the assembly) and continue execution in the interpreter
#   Consider the first the dump of GameOfLife.applyRules, we made an assumption and it was wrong
#
# Ref:
#    https://dl.acm.org/doi/10.1145/2542142.2542143 "An intermediate representation for speculative optimizations in a dynamic compiler"
#    https://ssw.jku.at/General/Staff/GD/APPLC-2013-paper_12.pdf "Graal IR: An Extensible Declarative Intermediate Representation"
#
# Other Graal Topics: Individual phases (Inlining, Parital Escape Analysis, Loop unrolling)...
#
# To get the dumps run:
$JAVA_HOME/bin/javac GameOfLife.java
$JAVA_HOME/bin/java -cp . GameOfLife input.txt output.txt 1
$JAVA_HOME/bin/java \
    -Dgraal.Dump=:3 -Dgraal.PrintGraph=Network -Dgraal.MethodFilter='*GameOfLife.*'  \
    -cp . GameOfLife input.txt output.txt 10

# Topic 2: Graal as a JIT for Truffle Languages ==============================================================
#
# How to implement dynamic languages such as JavaScript on the JVM?
# AST Interpreters
#     Abstract Syntax Tree - Another example of IR
#     PRO: Easy to write, Each node can execute itself
#     Consider the jsSource of js-java-game-of-life/src/main/java/org/graalvm/demo/GameOfLife.java
#     CON: Slow, Virtual Call from each node to the next
# Truffle magic!
#     Truffle is a language implementation framework
#         Uses annotations and code generation, uses Graal to make things fast
#     Each nodes keeps track of it's "specializations"
#         "specializations" just means "I've been executed with this type before"
#         e.g. JSAddNode ./graaljs/graal-js/src/com.oracle.truffle.js/src/com/oracle/truffle/js/nodes/binary/JSAddNode.java
#         Truffle makes it "easy" to express specializations
#     (Practical) Partial Evaluation
#         Assume our AST is stable and will not change (deopt if it does)
#         Inline all the calls you can until you can't inline anymore
#         Let Graal do it's thing
#         Truffle makes it "easy" to express deoptimizations and transfer to interpreter (e.g. new specialization automatically deoptimizes)
#
# Ref:
#     https://dl.acm.org/doi/10.1145/3062341.3062381 "Practical partial evaluation for high-performance dynamic language runtimes"
#     https://dl.acm.org/doi/10.1145/2384577.2384587 "Self-optimizing AST interpreters"
#     https://dl.acm.org/doi/10.1145/2384716.2384723 "Truffle: a self-optimizing runtime system"
#
# Other Truffle Topics: Truffle DSL, Truffle Tools API, Other languages (graalpython, truffle ruby, FastR, ...) Interop, Optimizations (Monomorphisation, Inlining, ...)
# To get the dumps run:
(cd js-java-game-of-life/ && $MAVEN package exec:exec)

# Topic 3: Graal as an AOT compiler ==========================================================================
#
# The JVM is an awesome piece of engineering!
#     Awesome for long running tasks (e.g. web server running for days)
#     Not ideal for short tasks (CLI tools, FaaS, ...)
#         Profiling overhead, interpreter is slow, ...
#     The cloud changed the game, e.g. Running a web server on a powerful machine is
#         Expensive when load is low
#         Might not be enough when load is super high
# Can we have Java without a JVM? Yes, AOT Compile JVM Bytecode - GraalVM Native Image
#     Closed world assumption, Java can load code at runtime, AOT can't
#     No room for Speculative Optimizations
#         See dump of GameOfLife#getAliveNeighbours on JIT and AOT to compare
#         Configure Graal to not speculate
#
# Ref:
#   https://dl.acm.org/doi/10.1145/3360610 "Initialize once, start fast: application initialization at build time"
#
# Other Native Image Topics: Profile-guided optimizations, Points-to analysis, Heap Snapshoting, Binary size optimizations, ...
#
# To get the dumps run:
$JAVA_HOME/bin/native-image \
    -H:Dump=:3 -H:PrintGraph=Network -H:MethodFilter='*GameOfLife.*'  \
    -cp . GameOfLife

# Let's check a "hello world" example to see the overhead of the JVM in the smallest example possible
$JAVA_HOME/bin/javac HelloWorld.java
/usr/bin/time --format='>> Elapsed: %es, CPU Usage: %P, MAX RSS: %MkB' $JAVA_HOME/bin/java HelloWorld
/usr/bin/time --format='>> Elapsed: %es, CPU Usage: %P, MAX RSS: %MkB' ./helloworld

# Interesting stuff? Check out internship opportunities
# https://www.graalvm.org/community/internship/
