# LTN Train Info Combinator

The [Logistic Train Network (LTN)](https://mods.factorio.com/mod/LogisticTrainNetwork) is awesome. It makes the trains run on time between arbitrary requesters and providers and takes away a lot of the pain when scaling up a factory build.

It has its quirks, though, none more visible than the signal output from the LTN train stop which is documented as "Expected train inventory after un-/loading is complete.".

This is the default and it results in trains arriving at a provider that may still contain freight or having picked up items from an inserter to report that cargo (This behavior can be changed by unchecking the 'Providers output existing cargo" per-map LTN setting).

The LTN Train Info Combinator (LTI for short) can be placed close to one or more train stops and provides the following signals to the Logistic Network:

- A signal for each item in a delivery. The signal can be the quantity requested or provided, the stack count or a binary "1" signal. Those signals are always the current delivery as scheduled by the LTN.

- Each delivery signal can be negated (returned as a negative value)
- Each delivery signal can be divided by a constant between 1 and 32, e.g. to split it evenly across multiple wagons.
- Virtual signals to denote whether the connected station is the requester or the provider of the delivery.
- Signal enabling, negation and signal type (quantity, stack count or binary) can be configured separately for provider and requester operations.

Everything can be configured through the GUI.

![image1](https://github.com/hgschmie/factorio-ltn-train-info/raw/main/portal/img-m1.png) ![image1](https://github.com/hgschmie/factorio-ltn-train-info/raw/main/portal/img-m2.png) ![image1](https://github.com/hgschmie/factorio-ltn-train-info/raw/main/portal/img-m3.png)

- Fully supports copy/paste, blueprinting and cloning
- Supports [Even Picker Dollies](https://mods.factorio.com/mod/even-pickier-dollies)
- Can connect to multiple stations simultaneously, when multiple deliveries arrive at the same time, the last one "wins".

## Provider operations

Signal differences in standard operation between LTN train stop (green signals) and the LTN Train Info combinator (red signals):

![image1](https://github.com/hgschmie/factorio-ltn-train-info/raw/main/portal/img-1.png)

In this case, the train arrived with 3.9k concrete items and picked up two copper plates from an inserter. The actual request is 100 iron plates.

When disabling the LTN config setting ("Providers output existing cargo"), the item signals for a provider are the same (virtual signals still differ between LTN train stop and the LTN Train Info combinator):

![image2](https://github.com/hgschmie/factorio-ltn-train-info/raw/main/portal/img-2.png)

## Requester operations

Signal differences in standard operation between LTN train stop (green signals) and the LTN Train Info combinator (red signals):

![image1](https://github.com/hgschmie/factorio-ltn-train-info/raw/main/portal/img-3.png)

For a requester station, LTN will only ever output the expected cargo in the train after the unload operation is complete. The actual delivery information is only available through the LTN Train Info combinator.

## Signal reference

- Virtual Signal 'T' - Train ID for the train that runs the current delivery
- Virtual Signal 'P' - 1 if a connected station is the provider for the delivery
- Virtual Signal 'R' - 1 if a connected station is the requester for the delivery
- Virtual Signal 'D' - All item quantities and stack sizes are divided by this factor (1..20)

## Credits/Acknowledgements

- `Optera` - LTN is awesome.
- `justarandomgeek` - FMTK. 'nuff said. While I prefer the Jetbrains tools, this made VSCode bearable
- `raiguard` - some of the framework code was either lifted or inspired by [flib](https://mods.factorio.com/mod/flib).
- `modo.lv` - I flat out stole the basic structure using a global called `this` from the stack combinator mod.
