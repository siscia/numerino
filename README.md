Numerino
========

Simple priority Queue in Elixir

For now the priority levels are hardcoded and are only 4: "critical", "high", "medium" and "low"

The queue can be started using

```
mix run --no-halt
```

from now on two endpoint are available.

`GET` will pop from the queue.
`POST` will push on on the queue.

The POST endpoint require a JSON to be sent, the JSON need two keys: `priority` and `element`.

The `priority` key will indicate the priority of the message, the `element` key can be anything.

When you pop from the queue with a `GET` request you will receive a pair {`priority` : `element`} or `EOF`.

If you receive an `EOF` it means that the queue is empty.

Contributing
============

Please!

To Do, Low Hanging fruit
------------------------

    [ ] Right now the queue is completely volatile, if the server crash for some reason all the job queue will be lost, it can be acceptable, or not.

    [ ] Only one, hardcoded queue is present, it should be possible to create new queue with custom level of priorities.

Rules
-----

Please, before to contribute, benchmark your work.

Is extremely simple to run the benchmark.

First of all you need [siege](https://www.joedog.org/siege-manual/#)

`sudo apt-get install siege`

Then you need to generate a benchmark, you can simply run

```
python generate_traffic.py siege_benchmark.txt 5000 
```

to generate a siege file (siege_benchmark.txt) which contains 5000 lines, 3 out of 4 call will be `POST` call, the last will be a `GET` call.

Now you can start `Numerino` with

```
cd numerino
mix run --no-halt
```

Now you can start your benchmark

```
siege -f siege_benchmark.txt -c 500 -b
```

Let the test run for a little bit, 20sec are enought.

Please move the number of concurent user (-c) up and down, try values such as 10, 25, 50, 100, 250, 500, 1000 on your local machine.

Also, do not forget the -b option, it means `benchmark`.

Retry the same test with your patch and without, and post the result.

