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
  a         Send the command to all characters
  all       Send the command to all characters
  @all      Send the command to all characters
  p         Send the command to party members
  party     Send the command to party members
  @party    Send the command to party members

Commands:
  start     Start tracking
  stop      Stop tracking
  analyze   Scan inventory and build list
  track     Specify which item(s) to track
  lot       Toggle automatic rolling on needed organs
  list      List needed organs

Command: track
Usage: organs [OPTIONS] track [TYPE]
Examples:
  organs all track both
  organs party track gorget
  organs track obi

Type:
  both      Track both Fotia Gorget and Hachirin-no-Obi
  gorget    Track Fotia Gorget
  obi       Track Hachirin-no-Obi
</pre>
