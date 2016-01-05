# Numerino

Simple in memory Priority Queue

Numerino aims to be a standard, rock solid priority queue for any necessities.

I try to follow the UNIX philosophy to do only one thing and do it extremelly well.

## Use cases

A priority queue can be used in a lot of different scenarios, I am not trying to assume how you will use but I am only trying to provide the best platform to let you accomplish your job.

Since I have done no asumption of how you are going to use `Numerino` I sticked to use only strings, these because I find string to be a great compromise between flexibility and human-friendliness.

The priority are internally rappresentent as string, as well is possible to enqueue only strings.

Example of use can be as a manager for a web crawler, or to manage CPU intenive work on a cluster, or pretty much anythig that need to be done in order.

## Work in progress

This is the very first release of `Numerino` I tried to provide the smallest useful piece of software I could come out with, there are pretty much no features but it is reasonably fast and reasonably correct.

I hope the community will use the project and suggest features and improvements to the software.

## About the code

If you look at the code it really looks like a joke, this README is likely longer than the code itself.

I tried my best to keep it as small and simple as possible, I rewrote it all several time and this is the best version I can come up with, it is also the smallest.

## Correctness

Write concurrent code is extremelly hard, I did my best by keeping the scope as small as possible and using very simple data structure, still there is nasty bug I am not able to fix.

In the case of a write immediately followed by a read on the same queue in a particular configuration of the queue itself, the system could reply like the write didn't take place yet, even if the write itself is been acknoledged, fortunately the message is not lost and it will show up in the next read.

I have actually no idea why this happen, and the only explaination I was able to give myself sound like a "compiler bug" so I don't really want to believe in that.

I want to reiterate that to reproduce this nasty bug the queue need to be in a particular configuration and that the write and read request are almost perfectly concurrent.

## Performance

The code is written in Elixir/Erlang as such it takes as much advantages as possible from many processor, better a slow machine with a lot of processor than a fast machine with few.

It is fast ?

'There is not such thing as fast, but only fast enough' - Cit. Joe Armstrong

For small - medium size workload, given the necessary hardware it should be fast enough, a benchmark using a cloud host is coming soon.

## Safeness

`Numerino` use only HTTP and don't have any authentication nor authorization mechanism, yet.

It means that you need to run it in your own local infrastracture and don't open it to the world.

## A word of caution

Before that I show you the API I need to clarify that `Numerino` is my first experience developing in Elixir/Erlang/OTP, I tried to do my best but obviously I could have get a lot of things in the wrong way.

I would suggest you to test it, see if it runs following your expectation and necessities then run it in a secure environment and finally, if everything went good use it in production.

You are also warmly encourange to send me an email (visible in my github profile) at any of those step, we can discuss about your expected load, the performace you need to achieve and the hardware you have available.

## Use

`Numerino` has been developed to manage a big number of queues, queues are cheap and you are encourange to start as many queues as you need, however they do use memory, very few memory but still significant, after you have done your job with your queue is still better to clean up.

`Numerino` provides a REST-like JSON API very scarse.

Every queue is a resource and you can create a new queue via a simple `POST` request.

The requets need only to know what priorities you are allocating for the queue.

If everything goes right, the response will provide the `name` of the queue you have just created.

To push a new object in the queue all you need is another `POST` request, to communicate the object you want to save in the queue and what priority associate with such object.

Finally to pop from the queue you only need a `GET` request with will respond with the first element in the queue and its priority.

### API

#### REQUEST

**Action:** Create New Queue

**Verb:** `POST`

**URL:** `/`

**Body:** ```{"priorities" : ["high", "medium", "low"]}```

#### RESPONSE

**Code:** 201

**Body:** ``` {"message":"New transient queue created","queue":{"name": "name_of_the_queue","priorities":["high", "medium", "low"],"type":"transient"},"status":"ok"}```

#### DESCRIPTION

The name of the queue is going to be a UUID version 4, something that will looks like this: `d384536bb80a405cb7a4dfe7ef1bcacd`, you will need the name for every action you are going to execute on the queue.

* * *

#### REQUEST

**Action:** Push

**Verb:** `POST`

**URL:** `/:name`

**Body:** ```{"priority" : "medium", "message" : "foo bar"}```

#### RESPONSE

**Code:** 200

**Body:** ``` {"message" : "foo bar", "priority" : "medium", "status" : "ok"}```

#### DESCRIPTION

The `:name` in the URL is the name that is been returned from the creation of the queue.

* * *

#### REQUEST

**Action:** Pop

**Verb:** `GET`

**URL:** `/:name`

#### RESPONSE

**Code:** 200

**Body:** ``` {"message" : "foo bar", "priority" : "medium" ,"status":"ok"}```

**Code:** 404

**Body:** ``` {"message":"Not element in the queue","status":"end_of_queue"}```

#### DESCRIPTION

The `:name` in the URL is the name that is been returned from the creation of the queue.

If the queue is not empty and at least an element is still on the queue you will get the first response, if the queue is empty you will get the second one.

* * *

#### REQUEST

**Action:** Delete Queue

**Verb:** `DELETE`

**URL:** `/:name`


#### RESPONSE

**Code:** 200

**Body:** ```{"message":"Successfully deleted queue: :name","status":"ok"}```

#### DESCRIPTION

The `:name` in the URL is the name that is been returned from the creation of the queue.

This operation is permanent, there is no way to retrieve the messages on the delete queue, it will free up space.



