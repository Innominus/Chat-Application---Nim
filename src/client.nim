import threadpool, asyncdispatch, asyncnet, protocol, terminal, locks, strutils

# Initialising variables
var 
    myLock: Lock
    input: string = ""
    username: string

const serverAddr: string = "ADD SERVER ADDRESS HERE"

# Procedure for making a connection to the server
proc connect(socket: AsyncSocket, serverAddr: string) {.async.} =
    echo("Connecting to ", serverAddr)
    await socket.connect(serverAddr, 7687.Port)
    echo("Connected!")

    while true:
        let line = await socket.recvLine()
        let parsed = parseMessage(line)
        eraseLine()
        echo("[", parsed.username, "]: ", parsed.message)
        setCursorXPos(0)
        withLock myLock: 
            stdout.write(input)
        
# The procedure called for writing to the terminal on a separate thread        
proc lineWriter(): string {.thread.} =
    
    {.cast(gcsafe).}:
        var 
            ch: char = getCh()
            msgSent: string
            
        # This whole while loop was necessary to rework how to type to the terminal. 
        # Originally if you received a message, it would delete whatever you were typing because of the inate functionality of the writing to terminal function
        # Instead, this saves whatever you type to a variable, character by character. Recreating return key functionality, and backspace functionality
        while true:
            case ch:
            of {'\n', '\r', '\c'}:
                acquire(myLock)
                eraseLine()
                echo("[", username, "]: ", input)
                msgSent = input
                input = ""
                release(myLock)
                return msgSent
            of 3.char: # Ctrl + C
                quit "Closed client"
            of {127.char, '\b'}: # backspace
                acquire(myLock)
                if input.len > 0:
                    input = input[0..^2]
                    eraseLine()
                    stdout.write(input)
                    setCursorXPos(input.len)
                release(myLock)
            else:
                withLock myLock: input.add ch
                input = replace(input, "\u0000", "")
                eraseLine()
                stdout.write(input)
                
            ch = getCh()
        
initLock(myLock)

# On startup, asks for a username to use on the server
echo("~~ENTER USERNAME~~")
username = stdin.readLine()

echo("Chat application started")

# Connecting to the server
var socket = newAsyncSocket()
asyncCheck connect(socket, serverAddr)

setCursorXPos(0)

# Spawning a new thread to the lineWriter procedure to type in your message, then sending the message to the server
var messageFlowVar = spawn lineWriter()
while true:
    if messageFlowVar.isReady():
        let message = createMessage(username, ^messageFlowVar)
        asyncCheck socket.send(message)
        messageFlowVar = spawn lineWriter()
    asyncdispatch.poll()       



