# Fiber Optics - A development perspective

This was mostly written to scratch an itch and to figure out how hard it is to write a Factorio mod from scratch.

Short answer: not hard, but the documentation could be better. There are some sharp edges in the way the event system and the item/entity relationship model works that made me scratch my head more often than I wanted.

What is still puzzling to me is that I need more code to manage the entities than the actual functionality. There are quite a few edge cases in how building works, which events to deal with etc.

Factorio is a pretty mature game (the core game experience is > eight years old) and a lot of mods were written a few years ago and are rarely updated and/or are abandoned. This is understandable but still occasionally frustrating to a relative newbie. There is hope that with the upcoming 2.0 release, the modder scene gets reinvigorated.


## How it is implemented

Every FOC consists of a primary entity (which is a _SimpleEntityWithOwner_) and a number of secondary entities which are usually managed by the control code:

- [*] An _ElectricalEnergyInterface_ entity which simulates the power draw of a connector (1 + number of network connections * 8) kW (1 kW idle, 9 kW with one, 17 kW with two network connections).

- A _PowerSwitch_ for the network connection points. This seems to be literally the only entity that can take copper wire connections that is not a power pole (which has its own issues with automatically connecting copper wires)

- 16 _Lamp_ entitities that are the i/o pins. Lamps are great because they are simple and provide an easy access point for circuit wires. This is the same technique that the compaktcircuits mod uses, except that it uses 16 instances of the same item and some trickery to keep the pins in the right spot. But then again, it does not support rotating the circuits.

- [*] Two more lamps that emulate the connection LEDs.

- [*] A single constant combinator that controls the on/off state of
  the LEDs

Entities that are marked with [*] are fully managed by the control code and are added and removed as needed. The connection points for the power and circuit cables (Power switch and Lamps) have corresponding items and are visible when blueprinting or copying a FOC. This is necessary to be able to blueprint the connection wires or reconnect wires when placing a blueprint over existing entities.

For each power network that has at least one FOC connected to it, there are additional 16 _Container_ entities that serve as connection points for the IO Pins.


### Does it have FPS impact / does that mod need additional CPU over vanilla?

Very, very minimal. As there are no events when connecting/disconnecting an electrical or circuit wire, the code needs to "poll" all existing FOCs occasionally and compare the state of things (power available, number of copper wires, what networks they are connected to) with the registered state and, if anything changes, disconnect and reconnect the IO Pins. Also, if a new power network is needed or an existing power networks loses its last connector, the connection boxes need to be added and removed.

The good news is that this happens only once every five seconds, does not do any find_entity or similar heavy operation but simply poll the registered entities. So the impact should be minimal, especially when the FOCs are in "steady state" (no connection/disconnections happening).

### Opportunities

- Nicer graphics. If you want to contribute, open an issue on github.

- A smaller (1x1) FOC would be nice. It would have fewer IO pins (maybe only 8). However, the picture gets really crowded (two LEDs and two connection points surrounded by eight IO Pins...). Also, with a subset of IO pins, there would need to be some GUI that allows connecting the pins to a specific fiber strand.

- Rotating the power connection points (and the LEDs) with the FOC would be nice. I don't think the power switch can be rotated.

- There are ways to store and restore information during cut/paste and blueprinting (compaktcircuit does it) which would allow to reduce the 16 different IO pin items to maybe 2 (one for pin 1, one for everything else)


## Observations

- It would be great to have a *generic "connects to electrical network" entity*. Similar to "simple-entity-with-owner", something where one can choose whether to require explicit copper cables or just being in a coverage area is enough. Being able to choose the energy consumption similar to the electrical-energy-interface but without having to fuzz around with input_flow_limit, output_flow_limit and buffer_capacity. Literally the only entity right now that explicitly connects to the power network with a copper cable is the power switch. An electric pole needs copper cables, too but in turn does things like "auto-connect to other power poles in close proximity" which breaks the illusion a bit.

- Same for a *generic "connect to circuit networks" entity*. A simple entity that one can configure to connect to the circuit network. Admittedly the lamp does a good job but it feels like "creative use".

- There are lots of "how to build a basic mod in Factorio" tutorials. I have not found a lot of good references about advanced modding. Reading a lot of code, it turns out that even for popular mods, part of the code has either aged (it may have been necessary to do things in a specific way in 0.17 but no longer in 1.1) or has defects.

- *entity building*. For building a compound entity such as the FOC, there is

  - standard construction that places a new entity. Fires `on_built_entity`.
  - non standard construction that places an entity. Other mods may fire `script_raised_built` or `script_raised_revive`.
  - robot construction. This is a whole world onto itself: regular construction places a ghost with the entity in it and then replaces it with the actual entity. This fires `on_built_entity` with the ghost first and then `on_built_entity` with the actual entity.
  - But that is not all. Because this is a compound entity (which consist of the main FOC entity and then additional, selectable entities for the IO Pins and the power connector), when doing cut and paste or blueprinting, those entities will be selected, too. Which is necessary because for cut and paste or blueprinting, to retain wire connections to other entities in the blueprint, those entities need to be picked up. And when they get put down (either through robot building for paste/blueprints in the regular game or instant building e.g. in the map editor), then these additional entities will be placed as well.
  - for all additional entities, regular build events (same as above) need to be processed as well, the entities need to be registered and when the main entity is built, it needs to "adopt" either the ghosts (to retain the wire connections of a blueprint or cut/paste) or the placed entities.
  - ghosts will always be placed before the actual entity. For non-ghosts ("instant construction" in the map editor e.g.), it is necessary that they are placed before the main entity. That is not always the case with blueprints. So any blueprint that picks up a FOC needs to look at all the additional entities that were also picked up and reorder those so that the additional entities are placed *before* the main FOC. Otherwise, the game will not place them. Reordering requires renaming all the entities in the blueprint...

  I can see a multi-part blog post/tutorial that explains all the hoops that are needed to make these things work so that the in-game illusion is retained.

- *blueprint flipping*. This is almost an arcane art onto itself. Flipping in Factorio terms means "replace north direction with south direction and vice versa for vertical flipping and east with west and vice versa for horizontal". This sounds trivial. But what if an entity is not symmetric?
  - For the FOC, flipping an entity that points north (green pin top left) horizontally should result in an entity where the green pin is top right. But that is not south. It is east.
  - Same for the IO Pins. An entity that points north has its IO Pins start top left (Pin 1) and go around clockwise. Flipping it means that Pin 1 is top right *and the pins go around counter-clockwise*. Which, btw, is different from an entity that points north and gets rotated so that Pin 1 is top right. In that case, the IO Pins keep going clockwise... Turns out there are eight different variations (four directions and pins clockwise/counterclockwise).

- *tag handling*. Another world of hurt. Creating tags for a blueprint is an arcane art that actually needs aligning entities to the entries in the blueprint by coordinate (not actually perfect, multiple entities may share the same coordinates) and name. Don't ever stack two identical entities on top of each other please. :-) But once the tags are on the blueprint, they get delivered by
  - the `on_built_entity` event if something is built directly
  - the ghost that is built first and then replaced with an entity by a robot. The code again needs to deal with the ghost entity (because the tags are now on the ghost. Not the build event for the ghost. The ghost itself), take the tags from there (and some other pieces such as player information), store them and make them available to the actual entity build (because now, the build event does *not* have the tags anymore...).

All of this make sense if one looks at it from the perspective of that giant stateful machine that Factorio is. But having to deal with four sets of events for building, two sets for deconstruction, two for blueprinting and a few more for singular things such as rotation requires a lot of code just for management.

- It would be _great_ if an item could be marked as "invisible" in the UI for cut/paste and blueprinting. Right now, when blueprinting/cut&pasteing a FOC, the power connector and the IO pins show up as extra items, even though the user can not construct them (and the code takes care of them). But they need to be in the blueprint so that connecting wires works. If they could be marked as "needed but invisible", it would tremendously reduce the visual clutter when blueprinting.

- *wire handling*. Ugh. I understand why there are no events for connecting/disconnecting and I can live with that but do the data structures for red/green wires and copper wires *really* have to be different enough that one can not write generic code? Inspecting ghosts, entities and blueprint items for existing wire connections is like an exercise in detective work and most of the time it is try-and-error. And then there are some small corners that are flat out undocumented.

- *docs*. The "official" Factorio `core/lualib` is basically undocumented. It also mixes low-level "basic" functionality with very specific use case methods (e.g. for trains).

- *stdlib and flib*. Spending time with those libraries, both of them have great nuggets of code. I pried some pieces out of flib to implement a little framework library. stdlib's event management system is fantastic. Sadly, stdlib seems abandoned (last commit was 18 months ago). I can see lifting more pieces out of it into framework and not building on top of stdlib any longer.

- *lua, the language*. Yes, it is the lingua franca of game programming. And if one is used to python/ruby/javascript or other interpreted languages, then the lack of type information and type safety may be ok. But, my god, a typed language with ahead-of-time type checking like Java, Typescript or golang would make life so much easier. Especially as there is not a lot of good ways of testing the code short of manual testing. Without FMTK I would have given up a long time ago.
