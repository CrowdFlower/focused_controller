# Focused Controller: Bringing Real OOP to Rails Controllers. #

[![Build Status](https://secure.travis-ci.org/jonleighton/focused_controller.png?branch=master)](http://travis-ci.org/jonleighton/focused_controller)


## Description ##

Classical Rails controllers violate the Single Responsibility Principle.

Each different "action" has separate responsibilities. The "create"
action does something entirely different to the "destroy" action, yet
they are lumped into the same object.

This has two unfortunate side effects:

1. *We end up using instance variables to share data with our views when
   we should really be using methods*. Using instance variables for this
   purpose makes it harder to change your implementation and can lead to
   subtle bugs. For example, referencing an undeclared instance variable
   in a view will work, when it should probably raise an error. We could
   define public methods in our controllers and access those in our views,
   but this will quickly get unmaintainable.

2. *Action-specific APIs are needed*. For example, you might write a
   `before_filter` which only applies to certain actions, so we have an
   API which allows you to write `before_filter :find_post, except:
   :index`. *If each 'action' is a separate object this is entirely
   unnecessary*. Just use the normal methods of sharing code -- inheritance
   and mixins -- to apply the filter to the actions which should receive
   them. A secondary effect is that filters are often themselves
   unnecessary; for example a `before_filter` might be replaced by a call
   to `super` to receive some shared behaviour.

Out of the box, Rails controller tests are not unit tests. They actually
generate a Rack environment hash and send it through the full stack. This is
very slow, and rather unnecessary if you are also writing acceptance
tests. Most of the code being exercised is in Rails rather than in your
controllers.

Focused Controller aims to make controllers like any other
object. That means they:

* Only have one reason to change
* Are easy to instantiate, with minimal dependencies, and testable in the
  same way as any other object: by calling their methods.

## Feedback needed ##

This project is in early stages, and while I have been using it
successfully on a production application, I'm very keen for others to
start experimenting with it and providing feedback.

Note that I will follow SemVer, and the project is currently pre-1.0, so
there could be API changes. However if the user base grows significantly
then I will try not to make changes too painful.

## Usage ##

Focused Controller changes Rails' conventions. Rather than controllers
being objects which contain one method per action, controllers become
namespaces which contain one class per action. Objects which wish to use
this convention include the `FocusedController::Mixin` module. This
means that you can start using Focused Controller in an existing
project without having to rewrite all your controller code.

An example:

``` ruby
module PostsController
  # Action is just used as a common superclass for all the actions
  # inside `PostsController`.
  class Action < ApplicationController
    include FocusedController::Mixin
  end

  class Index < Action
    def run
      # your code here
    end

    # No instance variables are shared with the view. Instead,
    # public methods are defined.
    def posts
      @posts ||= Post.all
    end

    # To prevent yourself having to write `controller.posts`
    # in the view, you can declare the method as a helper
    # method which means that calling `posts` automatically
    # delegates to the controller.
    helper_method :posts
  end

  # Actions do not need to declare a `run` method - the default
  # implementation inherited from `FocusedController::Mixin` is an
  # empty method.
  class Show < Action
    def post
      @post ||= Post.find params[:id]
    end
    helper_method :post
  end
end
```

## Routing ##

Rails' routing assumes your actions are methods inside an object whose
name ends with 'controller'. For example:

``` ruby
get '/posts/new' => 'posts#new'
```

will route `GET /posts/new` to `PostsController#new`.

To get around this, we can use the `focused_controller_routes` helper:

``` ruby
focused_controller_routes do
  get '/posts/new' => 'posts#new'
end
```

The route will now map to `PostsController::New#run`.

This is similar to writing:

``` ruby
get '/posts/new' => proc { |env| PostsController::New.call(env) }
```

All the normal routing macros are supported:

``` ruby
focused_controller_routes do
  resources :posts
end
```

## Functional Testing ##

Though it's not encouraged, focused controllers can be tested in the
classical 'functional' style. This can be a useful interim measure when
converting a controller to be properly unit tested.

It no longer makes sense to specify the action name to be called as the
action name is always "run". So this is omitted:

``` ruby
module UsersController
  class CreateTest < ActionController::TestCase
    include FocusedController::FunctionalTestHelper

    test "should create user" do
      assert_difference('User.count') do
        post user: { name: 'Jon' }
      end

      assert_redirected_to user_path(@controller.user)
    end
  end
end
```

There is also an equivalent helper for RSpec:

``` ruby
describe UsersController do
  include FocusedController::RSpecFunctionalHelper

  describe UsersController::Create do
    it "should create user" do
      expect { post user: { name: 'Jon' } }.to change(User, :count).by(1)
      response.should redirect_to(user_path(subject.user))
    end
  end
end
```

## Unit Testing ##

A better way to test your controllers is with unit tests. This involves
creating an instance of your action object and calling methods on it. For
example, to test that your `user` method finds the correct user, you
might write:

``` ruby
module UsersController
  class ShowTest < ActiveSupport::TestCase
    test 'finds the user' do
      user = User.create

      controller = UsersController::Show.new
      controller.params = { id: user.id }

      assert_equal user, controller.user
    end
  end
end
```

### The `#run` method ###

Testing the code in your `#run` method is a little more involved,
depending on what's in it. For example, your `#run` method may use
(explicitly or implicitly) any of the following objects:

* request
* response
* params
* session
* flash
* cookies

To make the experience smoother, Focused Controller sets up mock
versions of these objects, much like with classical functional testing.
It also provides accessors for these objects to your test class.

The fact that we have to do this is an indication of high coupling
between the controller and these other objects. In the future, I want to
look at ways to reduce this coupling and make the testing more
straightforward and obvious.

In the mean time, here is an example:

``` ruby
module UsersController
  class CreateTest < ActiveSupport::TestCase
    include FocusedController::TestHelper

    test "should create user" do
      assert_difference('User.count') do
        req user: { name: 'Jon' }
      end

      assert_redirected_to user_path(controller.user)
    end
  end
end
```

### The `req` helper ###

The `req` method runs the "request", but it does *not* go through the
Rack stack. It simply sets up the params, session, flash, and then calls
the `#run` method. The following are equivalent:

``` ruby
req({ x: 'x' }, { y: 'y' }, { z: 'z' })
```

``` ruby
controller.params = { x: 'x' }
session.update(y: 'y')
flash.update(z: 'z')
controller.run
```

### Assertions ###

You also have access to the normal assertions found in Rails' functional
tests:

* `assert_template`
* `assert_response`
* `assert_redirected_to`

However, I intend to consider alternatives to these. For example,

``` ruby
assert_equal users_path, controller.location
```

seems lot more straightforward and explicit to me than:

``` ruby
assert_redirected_to users_path
```

### Filters ###

We're not testing through the Rack stack. We're just calling the `#run`
method. Therefore, filters do not get run. This is a feature: if your
filter code is truly orthogonal to your controller code it should be
unit tested separately. If it is not orthogonal then you should find a
way to invoke it more explicitly than via filters.

(At this point I will ask: if it is truly orthogonal, why not make it a
Rack middleware?)

### RSpec ###

There is a helper for RSpec as well:

``` ruby
describe UsersController do
  include FocusedController::RSpecHelper

  describe UsersController::Create do
    test "should create user" do
      expect { req user: { name: 'Jon' } }.to change(User, :count).by(1)
      response.should redirect_to(user_path(subject.user))
    end
  end
end
```

## Isolated unit tests ##

It is possible to completely decouple your focused controller tests from the
Rails application. This means you don't have to pay the penalty of
starting up Rails every time you want to run a test. The benefit this
brings will depend on how coupled your controllers/tests are to other
dependencies.

Your `config/routes.rb` file is a dependency. When you use a URL helper
you are depending on that file. As this is a common dependency, Focused
Controller provides a way to stub out URL helpers:

``` ruby
module UsersController
  class CreateTest < ActiveSupport::TestCase
    include FocusedController::TestHelper
    stub_url :user

    # ...
  end
end
```

The `stub_url` declaration will make the `user_path` and `user_url`
methods in your test and your controller return stub objects. These can
be compared, so `user_path(user1) == user_path(user1)`, but
`user_path(user1) != user_path(user2)`.

## Speed comparison ##

Here's a comparison of running the same test in each of the different
styles:

### Functional ###

* **Test time**: 0.154842s, 45.2075 tests/s, 64.5821 assertions/s
* **Total time**: 3.380s

### Unit ###

* **Test time**: 0.046101s, 151.8393 tests/s, 216.9133 assertions/s
* **Total time**: 3.578s

### Isolated Unit ###

* **Test time**: 0.016669s, 419.9434 tests/s, 599.9191 assertions/s
* **Total time**: 2.398s

## More examples ##

The [acceptance
tests](https://github.com/jonleighton/focused_controller/test/acceptance)
for Focused Controller exercise a [complete Rails
application](https://github.com/jonleighton/focused_controller/test/app),
which uses the plugin. Therefore, you might wish to look there to get
more of an idea about how it can be used.

(Note that the code there is based on Rails' scaffolding, not how I
would typically write controllers and tests, necessarily.)
