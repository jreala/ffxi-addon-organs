# README

Work in Progress

## Organs
### Commands

<pre>
Usage: organs [OPTIONS] [COMMAND]
Examples:
  organs analyze
  organs all analyze
  organs party analyze

Options:
  a             Send the command to all characters.
  all           Send the command to all characters.
  @all          Send the command to all characters.
  p             Send the command to party members.
  party         Send the command to party members.
  @party        Send the command to party members.

Commands:
  start         Start tracking.
  stop          Stop tracking.
  analyze       Scan inventory and build list of items needed.
  track         Specify which item(s) to track.
  lot           Toggle automatic rolling on needed organs.
  list          List needed organs. This value is cached from when analyze runs and could potentialy be stale.
  infoarea      Specify chat log or console for info logs.
  debug         Enable debug logs.

Command: track
Usage: organs [OPTIONS] track [TYPE]
Examples:
  organs all track both
  organs party track gorget
  organs track obi

Type:
  both          Track both Fotia Gorget and Hachirin-no-Obi
  gorget        Track Fotia Gorget
  obi           Track Hachirin-no-Obi

Command: infoarea
Usage: organs [OPTIONS] infoarea [AREA]
Examples:
  organs all infoarea log
  organs infoarea console

Area:
  console       Log to the Windower console
  log           Log to the game chat log
</pre>
