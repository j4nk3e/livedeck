# Livedeck

To start your Phoenix server:

  * Run `mix setup` to install and setup dependencies
  * Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

Ready to run in production? Please [check our deployment guides](https://hexdocs.pm/phoenix/deployment.html).

## Flow

- Open deck on presenting device (called "presenter")
  - Presenter starts new session (can be password protected)
  - QR code for controller will be shown
- Scan QR code with controller
  - Controller registers with presenter and takes over control
  - Presenter jumps to title page
- Presenter shows QR code for participants on title page
  - Show bar with deck info, controller status and number of participants

## Goals

- Interactive presentation with viewer mode and polls
- Keep creation of slides simple and open (plaintext files, version control)
- As little configuration as possible
- Save stats to review after each session

### Non-goals

- Deck creation or management
- Complex layouting or deck building
