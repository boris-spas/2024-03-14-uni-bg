#!/usr/bin/env bash

source source_me.sh

# Graal as a JIT for the JVM ========================================================================
#
# .java -> javac -> .class -> | Interpreter ->  C1 -> C2            |
#                             |                   -> jvmci -> Graal |
#                             +-------------------------------------+
#                             |                JVM                  |
#
# Sea of nodes IR
# Speculative Optimizations
#   Check the dump of GameOfLife.applyRules, we made an assumption and it was wrong
#
# Ref:
#    https://dl.acm.org/doi/10.1145/2542142.2542143 "An intermediate representation for speculative optimizations in a dynamic compiler"
#    https://ssw.jku.at/General/Staff/GD/APPLC-2013-paper_12.pdf "Graal IR: An Extensible Declarative Intermediate Representation"
#
# Other Graal Topics: Individual phases (Inlining, Parital Escape Analysis)...
#
$JAVA_HOME/bin/javac GameOfLife.java
$JAVA_HOME/bin/java -cp . GameOfLife input.txt output.txt 1
$JAVA_HOME/bin/java \
    -Dgraal.Dump=:3 -Dgraal.PrintGraph=Network -Dgraal.MethodFilter='*GameOfLife.*'  \
    -cp . GameOfLife input.txt output.txt 10

# Graal as a JIT for Truffle Languages ==============================================================
#
# AST Interpreters
#   Easy to write
#   Slow
# (Practical) Partial Evaluation to the rescue
#   "Easy" to express specializations
#   "Easy" to express deoptimizations and transfer to interpreter
#
# Ref:
#   https://dl.acm.org/doi/10.1145/3062341.3062381 "Practical partial evaluation for high-performance dynamic language runtimes"
#   https://dl.acm.org/doi/10.1145/2384577.2384587 "Self-optimizing AST interpreters"
#   https://dl.acm.org/doi/10.1145/2384716.2384723 "Truffle: a self-optimizing runtime system"
#
# Other Truffle Topics: Truffle DSL, Tools API, Interop, Optimizations (Monomorphisation, Inlining, ...)
#
(cd js-java-game-of-life/ && $MAVEN package exec:exec)

# Graal as an AOT compiler ==========================================================================
#
# JVM in the  cloud world
#   JVM + micro services
# Java without a JVM?
#   AOT Java
#   Closed world assumption
# No room for Speculative Optimizations
#   See dump of GameOfLife#getAliveNeighbours on JIT and AOT to compare
# No room for reflection and dynamic class loading
#
# Ref:
#   https://dl.acm.org/doi/10.1145/3360610 "Initialize once, start fast: application initialization at build time"

$JAVA_HOME/bin/native-image \
    -H:Dump=:3 -H:PrintGraph=Network -H:MethodFilter='*GameOfLife.*'  \
    -cp . GameOfLife
$JAVA_HOME/bin/javac HelloWorld.java
/usr/bin/time --format='>> Elapsed: %es, CPU Usage: %P, MAX RSS: %MkB' $JAVA_HOME/bin/java HelloWorld
/usr/bin/time --format='>> Elapsed: %es, CPU Usage: %P, MAX RSS: %MkB' ./helloworld

# https://www.graalvm.org/community/internship/

# Q: Koju medjureprezentaciju koristi Graal?
# A: Sea of nodes

# Q: Koja optimizacija omogucuje JIT kompilaciju Truffle AST-eva?
# A: Partial Evaluation

# Q: True/False: Spekulativne optimizacije omogucuju:
#       a) Brzi startup AOT kompajliranog koda
#       b) Brzi startup JIT kompajliranog koda
#       c) Bolje optimizacije JIT kompajliranog koda
#       d) Bolje optimizacije AOT kompajliranog koda
# A: C

# Q: Closed world assumption znaci
#       a) Izvrsava se *minimalno*  onaj kod koji je kompajliran
#       b) Izvrsava se *maksimalno* onaj kod koji je kompajliran
#       c) Kompajliramo samo "hot" kod
#       d) Kompajliramo sav kod koji je dostupan
# A: B
