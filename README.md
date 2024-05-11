# Fiber Optics - A Factorio Mod

This was mostly written to scratch an itch and to figure out how hard it is to write a Factorio mod from scratch.

Short answer: not hard, but the documentation could be better. There are some sharp edges in the way the event system and the item/entity relationship model works that made me scratch my head more often than I wanted.

Factorio is a pretty mature game (the core game experience is > eight years old) and a lot of mods were written a few years ago and are rarely updated and/or are abandoned. This is understandable but still occasionally frustrating to a relative newbie. There is hope that with the upcoming 2.0 release, the modder scene gets reinvigorated.

## Credits / Acknowledgements

- `Telkine2018` for the compaktcircuit mod. This ultimately kicked off the idea of fiber-optics. Sadly, the module seems to be abandoned.
- `glutenfree` - fff-402-radars. I stole the trick of teleporting the connection boxes around before connecting
- `eradicator` - hand-crank-generator showed the usage of the ElectricEnergyInterface
- `justarandomgeek` - FMTK. 'nuff said. While I prefer the Jetbrains tools, this made VSCode bearable

Images by Stable Diffusion and GPT 4. Happy to take better graphics; I am a coder, not a graphics artist. Grateful that AI tools allow me to fake being a graphics artist.

This mod supports Picker Dollies; when moving the connector, all related entities will be moved with it.

## How it works

Did you know that modern power cables have a fiber core? Google "OPPC" or "optical phase conductor" if you don't believe me. What you don't know is that Factorio actually uses such cables. So every power cable that was ever placed in your factory actually has a number of optical fibers in it.

What can you do with that? Well, fiber optics is good for one thing: Transfer signals over long distances. However, up until now, there was no way to access them.

A Fiber Optics Connector (FOC) provides two sets of access points:

- up to 16 IO Pins for circuit signals. Each Pin fully supports bidirectional red and green signals
- two connection pins to connect to power networks.

When a connector is powered up (it needs to be placed in a coverage area) and connected to power grids using copper cables, one or both indicator lights will turn green. This signals that the connector has established a link to the fiber network. Connecting to the same network twice will only give one green light. Connecting to two networks and then merging them will drop one of the lights.

It can take up to five seconds for the lights to turn green (or turn red when disconnected).

The network does not need to be the same network that powers the Fiber Optics connector. It may even be preferred to power from the global power network but transfer signals across a smaller, isolated power network.

When connecting to multiple networks, the Fiber Optics Connector acts as a bidirectional bridge. Signals from one network will cross over to the other and vice versa.

Power switches break the fiber connections. If signals need to cross a power switch, connect one wire to each side of the power switch (the fiber optics connector does not transfer energy!).

Multiple fiber optics connectors form a bus across a power network. Each pin is fully connected to the same pin on all other FOCs. The current generation of FOCs can transfer up to 16 red and 16 green signals simultaneously across up to two power networks.

## How it is implemented

Every FOC consists of a primary entity (which is a _SimpleEntityWithOwner_) and a number of secondary entities which are usually managed by the control code:

- [*] An _ElectricalEnergyInterface_ entity which simulates the power draw of a connector (1 + number of network connections * 8) kW (1 kW idle, 9 kW with one, 17 kW with two network connections).

- A _PowerSwitch_ for the network connection points. This seems to be literally the only entity that can take copper wire connections that is not a power pole (which has its own issues with automatically connecting copper wires)

- 16 _Lamp_ entitities that are the i/o pins. Lamps are great because they are simple and provide an easy access point for circuit wires. This is the same technique that the compaktcircuits mod uses, except that it uses 16 instances of the same item and some trickery to keep the pins in the right spot. But then again, it does not support rotating the circuits.

- [*] Two more lamps that emulate the connection LEDs.

- [*] A single constant combinator that controls the on/off state of
  the LEDs

Entities that are marked with [*] are fully managed by the control code and are added and removed as needed. The connection points for the power and circuit cables (Power switch and Lamps) have corresponding items and are visible when blueprinting or copying a FOC. This is necessary to be able to blueprint the connection wires or reconnect wires when placing a blueprint over existing entities.

Note about flipping blueprints:

OCs have a marked "pin 1" and they can be rotated (the I/O pins rotate with them). When flipping a blueprint, Pin 1 will be flipped as well. This is fine (when pasting, the FOC will be drawn correctly) but as everything around it has been flipped, the cables may now look different than before.

For each power network that has at least one FOC connected to it, there are additional 16 _Container_ entities that serve as connection points for the IO Pins.

### Does it have FPS impact / does that mod need additional CPU over vanilla?

Sadly yes, but only a little bit. As there are no events when connecting/disconnecting an electrical or circuit wire, the code needs to "poll" all existing FOCs occasionally and compare the state of things (power available, number of copper wires, what networks they are connected to) with the registered state and, if anything changes, disconnect and reconnect the IO Pins. Also, if a new power network is needed or an existing power networks loses its last connector, the connection boxes need to be added and removed.

The good news is that this happens only once every five seconds, does not do any find_entity or similar heavy operation but simply poll the registered entities. So the impact should be minimal, especially when the FOCs are in "steady state" (no connection/disconnections happening).

### Opportunities

- Nicer graphics. If you want to contribute, open an issue on github.

- A smaller (1x1) FOC would be nice. It would have fewer IO pins (maybe only 8). However, the picture gets really crowded (two LEDs and two connection points surrounded by eight IO Pins...). Also, with a subset of IO pins, there would need to be some GUI that allows connecting the pins to a specific fiber strand.

- It is possible to pick up IO pins with the Pipette. Don't do that. If you drop an IO pin item (or place it), there will be single IO pins lying around in your factory. Those are not good for anything (they are managed by a FOC).

- "half" selected OCs that do not have all the IO Pins. This is more an annoyance than an actual issue (as the control code will create the remaining pins) but it would be nice to ensure that selecting half of an FOC will pick up all the IO pins.

- There are ways to store and restore information during cut/paste and blueprinting (compaktcircuit does it) which would allow to reduce the 16 different IO pin items to maybe 2 (one for pin 1, one for everything else)

- Rotating the power connection points (and the LEDs) with the FOC would be nice. I don't think the power switch can be rotated.

- Support for flipped entities would be nice. It is possible to receive the flip information ahead of time (`on_pre_build` event, `flip_horizontal` and `flip_vertical`). Being able to take that information, draw the image correctly and move the IO pins around would make for a better experience.

## Wishlist

Some annoyances that I felt while putting this together:

- It would be great to have a generic "connects to electrical network" entity. Similar to "simple-entity-with-owner", something where one can choose whether to require explicit copper cables or just being in a coverage area is enough. Being able to choose the energy consumption similar to the electrical-energy-interface but without having to fuzz around with input_flow_limit, output_flow_limit and buffer_capacity. Literally the only entity right now that explicitly connects to the power network with a copper cable is the power switch. An electric pole needs copper cables, too but in turn does things like "auto-connect to other power poles in close proximity" which breaks the illusion a bit.

- Same for "connect to circuit networks". A simple entity that one can configure to connect to the logistics network. Admittedly the lamp does a good job but it feels like "creative use".

- There are multiple ways on how entities are constructed and deconstructed. Undo is a special favorite. Cut an entity (works fine, the robot picks up the primary and the control code removes everything else). Now press undo. Ghosts appear for the secondaries that have items associated. The robot only constructs the primary, because not items are available for the secondaries. Now the primary must not just create new secondaries (because the ghosts would be left behind) but look for the ghosts and "adopt them" instead of creating secondary entities. And they need to be adopted, because otherwise, the wire connections get lost.

- The pipette is a general annoyance because it is not possible to mark an entity as "not pipettable". If there is an item associated, you can pick it up from an entity.

- It would be _great_ if an item could be marked as "invisible" in the UI for cut/paste and blueprinting. Right now, when blueprinting/cut&pasteing a FOC, the power connector and the IO pins show up as extra items, even though the user can not construct them (and the code takes care of them). But they need to be in the blueprint so that connecting wires works. If they could be marked as "needed but invisible", it would tremendously reduce the visual clutter when blueprinting.

- docs. Both the "official" factorio `core/lualib` and the "unofficial" support libraries (`stdlib` and `flib`) are basically undocumented. Especially stdlib with its heavy use of meta tables could benefit a lot from better docs. All three of these libraries mix lowlevel "foundational" functionality with very specific use case methods (e.g. for trains). I looked at all of those and decided that it is not worth spending time trying to figure out what is in there but just reimplement.
