import asyncdispatch, asyncnet

# Creating the Client and Server objects
type
    Client = ref object
        socket: AsyncSocket
        netAddr: string
        id: int
        connected: bool

    Server = ref object
        socket: AsyncSocket
        clients: seq[Client]

# Create a new server with an empty client list
proc newServer(): Server =
    Server(socket: newAsyncSocket(), clients: @[])

proc `$`(client: Client): string =
    $client.id & "(" & client.netAddr & ")"

# Processing received messages and sending them to all connected clients
proc processMessages(server: Server, client: Client) {.async.} =
    while true:
        let line = await client.socket.recvLine()
        if line.len == 0:
            echo(client, " disconnected!")
            client.connected = false
            client.socket.close()
            return

        echo(client, " sent: ", line)
        for c in server.clients:
            if c.id != client.id and c.connected:
                await c.socket.send(line & "\c\l")

# Main server loop put into a procedure
# Takes the server and binds the address to port 7687 and then listens for requests
proc loop(server: Server, port=7687) {.async.} = 
    server.socket.bindAddr(port.Port)
    server.socket.listen()

    # On receiving a connection, adds them to the client list, and checks for messages
    while true:
        let (netAddr, clientSocket) = await server.socket.acceptAddr()
        echo("accepted connection from ", netAddr)
        let client = Client(
            socket: clientSocket,
            netAddr: netAddr,
            id: server.clients.len,
            connected: true
        )
        server.clients.add(client)
        asyncCheck processMessages(server, client)


var server = newServer()

waitFor loop(server)
