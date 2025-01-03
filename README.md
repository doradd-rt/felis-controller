Run the Controller
==================

The felis-controller is written in scala, and is basically a
configuration provider and action coordinator for the nodes.

We have switched from sbt to Mill. Mill is much faster than sbt,
especially when combining with the OpenJ9 VM installed on our cluster.

Configuring the Nodes
---------------------

We use a JSON config file to keep the node configuration.
`config.json` is an example. The two parts you should be configuring
is `nodes` and `controller`.

`nodes` specifies the name of the node, the ssh hostname (for running
the experiment script). You also need to specify a worker socket (the
main database worker), and an index shipper socket (deprecated). If
you're working on data migration, you need to specify a row shipper
socket, similar to the index shipper.

`controller` part specifies the rpc port other nodes will connect to,
and the http port the controller receives command from (curl). See
readme on felis side.

Setting Up OpenJ9 (Optional)
----------------------------

This is optional, you can use the Hotspot JDK as well (but make sure
you are using JDK11), but OpenJ9 is much faster due to its ability to
AOT Java code.

On our cluster, OpenJ9 (JDK11) is already installed at
`/pkg/java/j9`. You need to:

	export PATH=/pkg/java/j9/bin:$PATH
	export JAVA_HOME=/pkg/java/j9

Compile and Run the Controller
------------------------------

To build the felis-controller jar, use:

	mill FelisController.assembly

This will generate a standalone jar
`out/FelisController/assembly.dest/out.jar`. Usually, you can run that
jar directly.

	java -jar out/FelisController/assembly.dest/out.jar config.json

But if you are sharing the machine with someone else, you need to
avoid the cache dir conflict. For example:

	java -Dvertx.cacheDirBase=/tmp/$USER/ -jar out/FelisController/assembly.dest/out.jar config.json


Run the Experiment Script
=========================

In addition to running the controller and nodes by yourself, we have
scripts to run experiments automatically. You still need to write
the configuration JSON though.

First, build a jar:

	mill FelisExperiments.assembly
	
Now you can run:

	java -jar out/FelisExperiments/assembly.dest/out.jar runXXX

For instance, `runYcsb` or `runHotspotTpcc`. See the code for further
details.

If you are sharing the machine with someone else, you can tell the
script to use your own port for the controller.

	java -Dcontroller.host=127.0.0.1:3148 -Dcontroller.http=127.0.0.1:8666 -jar out/FelisExperiments/assembly/dest/out.jar runXXX

