# MIPS32 Assembley Virtual Pet

An interactive Digital Pet Simulator written entirely in **MIPS32 Assembly Language**. This project simulates a pet's life cycle with real-time energy mechanics, file persistence, and dynamic user interaction.

---

## Game Overview
In this simulation, you manage a pet's energy levels. Energy depletes naturally over time based on a rate you define. You must interact with your pet through various commands to keep it alive and healthy.

### Interaction Multipliers
| Command | Action | Multiplier | Effect |
|:--- |:--- |:--- |:--- |
| **F** | Feed | 1x | Increases energy slightly |
| **E / P** | Entertain/Pet | 2x | Boosts energy significantly |
| **I** | Ignore | -3x | Drastically reduces energy |

---

## Technical Features

* **Temporal Logic:** Uses System Time (Syscall 30) to track elapsed time between user inputs, ensuring energy depletes even while the program waits for a command.
* **Persistence (File I/O):** Features a "Save/Load" system using MIPS file descriptors to write current energy states and session time to `pet_save.dat`.
* **Input Validation:** Implements custom string-to-integer conversion and input buffer flushing to prevent crashes from invalid data types.
* **Visual Feedback:** A procedural ASCII progress bar renders the current energy status relative to the Maximum Energy Level (MEL).
* **State Management:** Utilises the MIPS stack (`$sp`) and saved registers (`$s0-$s7`) to maintain game state across nested function calls.



---

## Getting Started

### Prerequisites
* [MARS (MIPS Assembler and Runtime Simulator)](http://courses.missouristate.edu/kenvollmar/mars/) or [SPIM](http://spimsimulator.sourceforge.net/).

### Running the Simulator
1.  Open MARS.
2.  File -> Open -> `pet_simulator.asm`.
3.  **Assemble** the code (Click the wrench icon or press `F3`).
4.  **Run** the code (Click the play icon or press `F5`).
5.  Follow the on-screen prompts to set your EDR (Energy Depletion Rate) and MEL (Maximum Energy Level).

---

## Commands List
- `F <units>` : Feed the pet.
- `E <units>` : Entertain the pet.
- `P <units>` : Pet the pet.
- `I <units>` : Ignore the pet.
- `H` : Halt (Pause) the game.
- `R` : Reset (Revive) the pet.
- `Q` : Quit (Saves state before exiting).
