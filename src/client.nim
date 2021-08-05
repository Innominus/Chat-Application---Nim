import threadpool, asyncdispatch, asyncnet, protocol, terminal, locks, strutils


var 
    myLock: Lock
    input: string = ""
    username: string

const serverAddr: string = "206.189.92.126"

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
        
        
proc lineWriter(): string {.thread.} =
    
    {.cast(gcsafe).}:
        
        var 
            ch: char = getCh()
            msgSent: string

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

echo("~~ENTER USERNAME~~")
username = stdin.readLine()

echo("Chat application started")

var socket = newAsyncSocket()
asyncCheck connect(socket, serverAddr)

setCursorXPos(0)
var messageFlowVar = spawn lineWriter()
while true:
    if messageFlowVar.isReady():
        let message = createMessage(username, ^messageFlowVar)
        asyncCheck socket.send(message)
        messageFlowVar = spawn lineWriter()
    asyncdispatch.poll()       



