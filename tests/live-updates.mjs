// Usage: node live-updates.mjs <websocket url> <channel> <event> <command that sends the event...>
import { execFileSync } from 'node:child_process'

const [url, channel, event, ...sendCommand] = process.argv.slice(2)
const socket = new WebSocket(url)

const timeout = setTimeout(() => {
  console.error(`No "${event}" event arrived on "${channel}".`)
  process.exit(1)
}, 30_000)

socket.onerror = error => {
  console.error('WebSocket error:', error.message)
  process.exit(1)
}

socket.onmessage = ({ data }) => {
  const message = JSON.parse(data)

  if (message.event === 'pusher:connection_established') {
    socket.send(JSON.stringify({ event: 'pusher:subscribe', data: { channel } }))
  }

  if (message.event === 'pusher_internal:subscription_succeeded') {
    execFileSync(sendCommand[0], sendCommand.slice(1), { stdio: 'inherit' })
  }

  if (message.event === event) {
    clearTimeout(timeout)
    console.log(`Received "${event}" on "${channel}".`)
    process.exit(0)
  }
}
