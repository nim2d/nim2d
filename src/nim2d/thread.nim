## Background threads and channels.
##
## SDL, the GPU and all drawing are main-thread affairs, so threads here are for
## work off to the side: loading files, decoding, generation. A thread runs a
## top-level proc marked `{.thread.}`, and a channel passes messages between
## threads. Messages are copied as they cross, so a value or a string travels
## safely; share data through a channel rather than through globals you mutate.
##
## A channel is usually a module-level global so both the worker proc and the
## main loop can name it, since a thread proc takes no captured state.

import std/typedthreads

type
  Thread2d* = ref object
    ## A running background thread.
    handle: Thread[void]

  Channel2d*[T] = object
    ## A typed, thread-safe queue of messages. Make one with `newChannel`.
    chan: ptr Channel[T]

proc newThread*(fn: proc() {.thread, nimcall.}): Thread2d =
  ## Start a thread running `fn`. The proc must be a top-level `{.thread.}` proc,
  ## not a closure, so it carries no captured variables.
  result = Thread2d()
  createThread(result.handle, fn)

proc join*(t: Thread2d) =
  ## Wait for the thread to finish.
  joinThread(t.handle)

proc isRunning*(t: Thread2d): bool =
  ## Whether the thread is still running.
  t.handle.running

proc newChannel*[T](): Channel2d[T] =
  ## Make an open channel carrying messages of type T.
  result.chan = cast[ptr Channel[T]](allocShared0(sizeof(Channel[T])))
  result.chan[].open()

proc send*[T](c: Channel2d[T], msg: sink T) =
  ## Send a message. A copy of the message crosses to the receiver.
  c.chan[].send(msg)

proc receive*[T](c: Channel2d[T]): T =
  ## Receive a message, blocking until one arrives.
  c.chan[].recv()

proc tryReceive*[T](c: Channel2d[T]): tuple[received: bool, msg: T] =
  ## Receive a message if one is waiting, without blocking.
  c.chan[].tryRecv()

proc peek*[T](c: Channel2d[T]): int =
  ## How many messages are waiting (negative if the channel is closed).
  c.chan[].peek()

proc close*[T](c: var Channel2d[T]) =
  ## Close the channel and free it. Do this after the threads using it are done.
  if c.chan != nil:
    c.chan[].close()
    deallocShared(c.chan)
    c.chan = nil
