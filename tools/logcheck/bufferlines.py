import sys, asyncio, argparse

async def readTask (queue):
    loop = asyncio.get_event_loop ()

    reader = asyncio.StreamReader()
    protocol = asyncio.StreamReaderProtocol(reader)
    await loop.connect_read_pipe(lambda: protocol, sys.stdin)

    while not reader.at_eof ():
        l = await reader.readline ()
        await queue.put ((loop.time (), l))
    await queue.put ((None, None))

async def writeTask (queue, maxLines=100, maxAge=5, command='cat'):
    loop = asyncio.get_event_loop ()
    nextFlush = []
    oldestLine = None
    done = False
    while not done or nextFlush:
        now = loop.time ()
        l = None
        lineTime = None
        try:
            lineTime, l = await asyncio.wait_for (queue.get (), timeout=now-oldestLine+maxAge if oldestLine else None)
            # Requested exit.
            if lineTime is None and l is None:
                done = True
        except asyncio.exceptions.TimeoutError:
            pass

        now = loop.time ()

        if l is not None:
            if not nextFlush:
                oldestLine = lineTime
            nextFlush.append (l)

        if now-oldestLine >= maxAge or len (nextFlush) >= maxLines:
            task = await asyncio.create_subprocess_shell (command, stdin=asyncio.subprocess.PIPE)
            for l in nextFlush:
                task.stdin.write (l)
            await task.stdin.drain ()
            task.stdin.close ()
            await task.stdin.wait_closed ()
            nextFlush = []
            oldestLine = None

async def main ():
    parser = argparse.ArgumentParser(
                        prog = 'ProgramName',
                        description = 'What the program does',
                        epilog = 'Text at the bottom of help')
    parser.add_argument('-t', '--timeout', type=int)
    parser.add_argument('-l', '--lines', type=int)
    parser.add_argument('command', nargs='+')
    args = parser.parse_args()

    queue = asyncio.Queue (args.lines+1)
    read = asyncio.create_task (readTask (queue))
    write = writeTask (queue, maxLines=args.lines, maxAge=args.timeout, command=' '.join (args.command))
    await asyncio.wait ([read, write])

asyncio.run (main ())

