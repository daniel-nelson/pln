One `Agent` call with `agentType: 'general-purpose'` (see Spawning a fresh-context agent), whose prompt points it at the brief file: "Read `<path to the brief>` in full and follow it. Your final message is your findings, in the shape the brief asks for." Point at the file rather than pasting its text back in — a same-model agent on this host can open it, the brief already carries the plan whole, and this way the reviewer reads byte-for-byte what a peer would have been sent.

The call's return value is that final message, and it is the only thing that reaches your context.
