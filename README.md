# Fiber Optics Connector

Did you know that modern power cables have a fiber core? Google "OPPC" or "optical phase conductor" if you don't believe me. What you don't know is that Factorio actually uses such cables. So every power cable that was ever placed in your factory has a number of optical fibers in it.

What can one do with that? Fiber optic cables are good for one thing: Transferring signals over long distances. However, up to now, there was no way to use them.

A Fiber Optics Connector (FOC) provides two sets of access points:

- up to 16 IO Pins for circuit signals. Each Pin fully supports bidirectional red and green signals
- two power pins to connect to power networks.

When a connector is powered up (it needs to be placed in a coverage area) and connected to one or more power grid using copper cables, one or both indicator lights will turn green. This signals that the connector has established a link to the fiber optic cables and is ready to send and receive signals from other FOCs on the same power network.

Connecting to the same power network twice will only give one green light. Connecting to two networks and then merging them will drop one of the lights.

It can take up to five seconds for the lights to turn green (or turn red when disconnected).

The power network does not need to be the same network that provides power to the Fiber Optics connector. It may even be preferential to provide power from the global power network but transfer signals across a smaller, isolated network.

When connecting to multiple networks, the Fiber Optics Connector acts as a bidirectional bridge. Signals from one network will cross over to the other and vice versa.

Power switches break the fiber connections. If signals need to cross a power switch, connect one wire to each side of the power switch (the fiber optics connector does not transfer energy!).

Multiple fiber optics connectors form a bus across a power network. Each pin is fully connected to the same pin on all other FOCs. The current generation of FOCs can transfer up to 16 red and 16 green signals simultaneously across up to two power networks.

This mod supports Picker Dollies; when moving the connector, all related entities will be moved with it.

## Credits / Acknowledgements

- `Telkine2018` for the compaktcircuit mod. This ultimately kicked off the idea of fiber-optics.
- `glutenfree` - fff-402-radars. I stole the trick of teleporting the connection boxes around before connecting
- `eradicator` - hand-crank-generator showed the usage of the ElectricEnergyInterface
- `justarandomgeek` - FMTK. 'nuff said. While I prefer the Jetbrains tools, this made VSCode bearable
- `modo.lv` - I flat out stole the basic structure using a global called `this` from the stack combinator mod.

Images by Stable Diffusion and GPT 4. Happy to take better graphics; I am a coder, not a graphics artist. Grateful that AI tools allow me to fake being a graphics artist.
