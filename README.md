# Modular and Parameterized CNN Accelerator with Systolic Convolution Arrays and Windowless Continuous Parallel Max-Pooling

The aim of this project is to optimize the CNN network to the hardware level, facilitating data reuse, parallel processing, efficient data flow, reduction in ports and IO load for real world use. Also, to make the system truly modular.

<img src="resources/3layercnn.jpeg" alt="3 Layer CNN model used in this project" title="3 Layer CNN model used in this project" width="75%"/>

Layer can be made modular so we are not limited to pre-defined number of layers, so at the final synthesis/application stage, we can test the proposed CNN model out considering system constraints, etc., by simply arranging the modular layers.

<img src="resources/cnnlayermodule.jpeg" alt="a modular CNN layer" title="a modular cnn layer" width="75%"/>

### Systolic array:
Systolic arrays are suitable for data reuse, and parallel process data, eliminates buffer memory for sliding window naive methods.

<img src="resources/systolicarray.jpeg" alt="a modular systolic array for convolution" title="a modular systolic array for convolution" width="75%"/>

ReLU can be implemented as a simple comparator logic at the end of the accumulator logic inside systolic array module.

### Processing and delay element:

<p align="center">
  <img src="resources/processingelement.jpeg" alt="Processing Element" title="Processing Element" width="45%"/>
  <img src="resources/delayelement.jpeg" alt="Delay Element" title="Delay Element" width="45%"/>
</p>

Systolic arrays operate rhythmically, where data is continuously flowing, responding to the clock cycle and is synchronized. The version presented above is tailored for convolution, where the inputs should be staggered. If there exists an input element matrix of _n rows_ and _m columns_, and a kernel element matrix of _u rows_ and _v columns_, the systolic array shall be of dimension _n x u_.

### Windowless Max Pooling:

As for Max pooling, instead of sliding windows with stride, we parallel process it using the mentioned methods further in the main document.

<img src="resources/maxpooler.jpeg" alt="Maxpooling module Windowless" title="Maxpooling Module Windowless" width="75%"/>

For windowless operation, we just take “POOL_SIZE” amount of columns streamed one column at a time, compare them every cycle, along with appropriate STRIDE taken, and determine the maximum value in the pool size. And after POOL_SIZE amount of columns are over, we output/write it to max pool buffer, and continue till end.  
The windowless operation is totally based on counters and control logic.

It gets more effective with increase in size.

![Maxpooler RTL](/resources/maxpoolerCL.png "Maxpooler RTL")



### Small sample Systolic array RTL elaboration:
Even a small systolic array has complex control logic involving muxes, and flags, counters.

![Systolic array RTL](/resources/SystolicarrayCL.png "Systolic array RTL")

## Simulation Waveforms for Proof of concept:

### Single Layer CNN system:

![Single Layer CNN system](/resources/singlelayercnnwv.png "Single Layer CNN system")

### 3 Layer CNN system:

![3 Layer CNN system part 1](/resources/3layercnn1wv.png "3 Layer CNN system part 1")
![3 Layer CNN system part 2](/resources/3layercnn2wv.png "3 Layer CNN system part 2")

### Max Pooling Module:

![Max Pooling Module](/resources/maxpoolwv.png "Max Pooling Module")

### Systolic array module:

![Systolic array module part 1](/resources/systolicarray1wv.png "Systolic array module part 1")
![Systolic array module part 2](/resources/systolicarray2wv.png "Systolic array module part 2")

For further details [click here](/cnnsystolic- doc PDF.pdf).
