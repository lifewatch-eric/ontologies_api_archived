# ontologies_api

ontologies_api provides a RESTful interface for accessing [BioPortal](https://bioportal.bioontology.org/) (an open repository of biomedical ontologies). Supported services include downloads, search, access to terms and concepts, text annotation, and much more.

## Prerequisites

- [Ruby 2.x](http://www.ruby-lang.org/en/downloads/) (most recent patch level)
- [rbenv](https://github.com/sstephenson/rbenv) and [ruby-build](https://github.com/sstephenson/ruby-build) (optional)
    - If you need to switch Ruby versions for other projects, you may want to install something like rbenv to manage your Ruby environment.
- [Git](http://git-scm.com/)
- [Bundler](https://bundler.io/)
- [4store](https://github.com/ncbo/4store)
    - BioPortal relies on 4store as the main datastore
    - For starting, stopping, and restarting 4store easily, you can try setting up [4s-service](https://gist.github.com/4211360)
- [Redis](http://redis.io)
    - Used for caching (HTTP, query caching, Annotator cache)
- [Solr](http://lucene.apache.org/solr/)
    - BioPortal indexes ontology class and property content using Solr (a Lucene-based server)

## Configuring Solr

To configure Solr for ontologies_api usage, modify the example project included with Solr by doing the following:

    cd $SOLR_HOME
    cp example ncbo
    cd $SOLR_HOME/ncbo/solr
    mv collection1 core1
    cd $SOLR_HOME/ncbo/solr/core1/conf
    # Copy NCBO-specific configuration files
    cp `bundle show ontologies_linked_data`/config/solr/solrconfig.xml ./
    cp `bundle show ontologies_linked_data`/config/solr/schema.xml ./
    cd $SOLR_HOME/ncbo/solr
    cp -R core1 core2
    cp `bundle show ontologies_linked_data`/config/solr/solr.xml ./
    # Edit $SOLR_HOME/ncbo/solr/solr.xml
    # Find the following lines:
    # <core name="NCBO1" config="solrconfig.xml" instanceDir="core1" schema="schema.xml" dataDir="data"/>
    # <core name="NCBO2" config="solrconfig.xml" instanceDir="core2" schema="schema.xml" dataDir="data"/>
    # Replace the value of `dataDir` in each line with: 
    # /<your own path to data dir>/core1
    # /<your own path to data dir>/core2
    # Start solr
    java -Dsolr.solr.home=solr -jar start.jar
    # Edit the ontologieS_api/config/environments/{env}.rb file to point to your running instance:
    # http://localhost:8983/solr/NCBO1

## Installing

### Clone the repository

```
$ git clone git@github.com:ncbo/ontologies_api.git
$ cd ontologies_api
```

### Install the dependencies

```
$ bundle install
```

### Create an environment configuration file

```
$ cp config/environments/config.rb.sample config/environments/development.rb
```

[config.rb.sample](https://github.com/ncbo/ontologies_api/blob/1e68882df83cf78cbb78281b1447c303c783e4c2/config/environments/config.rb.sample) can be copied and renamed to match whatever environment you're running, e.g.:

production.rb<br />
development.rb<br />
test.rb

### Run the unit tests (optional)

Requires a configuration file for the test environment:

```
$ cp config/environments/config.rb.sample config/environments/test.rb
```

Execute the suite of tests from the command line:

```
$ bundle exec rake test 
```

### Run the application

```
$ bundle exec rackup --port 9393 
```

Once started, the application will be available at localhost:9393.

## Contributing

- Fork the repository
- New features and bug fixes should be developed in their own branch
- Please add tests for any changes
- Pull requests are accepted and encouraged
    
## Workflow
There are a few ways to work with the code and run the application. The three things you will likely do the most often is 1) run the application with code reloading enabled 2) run the console and 3) run tests

### Code reloading
We can use a library called [Shotgun]() to force our entire application to reload on each request. This allows you to make a change in a file, hit refresh in a browser, and see the changes reflected. To load the application using Shotgun, simply run:

`bundle exec shotgun`

Once it has started, the application will be available on localhost:9393 (by default, this can be changed). Running via this method will work pretty much like every other server-based environment you have used in the past.

#### Debugging
If you want to insert a breakpoint, simply go to the code and add `binding.pry` on a line by itself. When you make a request, the application will stop at that point in the code and you can inspect objects and local variables easily. Type `ls` to see a list of local variables and methods that are available to run.

### Testing
Tests can be created under the top-level `test` folder in the corresponding section (model, controller, etc). Tests are written using the Ruby default [Test::Unit library](http://en.wikibooks.org/wiki/Ruby_Programming/Unit_testing). Many projects will have a base test class that initializes the environment as needed (e.g. [`test_case.rb`](https://github.com/ncbo/ontologies_api/blob/master/test/test_case.rb) from ontologies_api).

To run tests, just use ruby to call the class:

`ruby test/controllers/test_user_controller.rb` (from ontologies api)

You can put breakpoints using `binding.pry` and interact with the code directly from the test.

#### Rake
You can also invoke full test suites or run all tests with rake (Ruby Make). To see the available rake tasks, run `rake -T` from the project folder. Generally, running `rake test` will execute all tests.

### Console
You can load a pry session that has been bootstrapped with the project environment:

`bundle exec rackup -E console`

This will put you into the application at a point where you can invoke code. For example, you could create and save new Goo models, make requests using methods from [Rack::Test](http://www.sinatrarb.com/testing.html), or access variables, settings, etc set for the project.

## Components

### Controllers
Sinatra routes can be defined in controller files, found in the /controllers folder. All controller files should inherit from the ApplicationController, which makes methods defined in the ApplicationController available to all controllers. Generally you will create one controller per resource. Controllers can also use helper methods, either from the ApplicationHelper or other helpers.

### Helpers
Re-usable code can be included in helpers in files located in the /helpers folder. Helper methods should be created in their own module namespace, under the Sinatra::Helpers module (see MessageHelper for an example).

### Libraries
The /lib folder can be used for organizing complex code or Rack middleware that doesn't fit well in the /helpers or /models space. For example, a small DSL for defining relationships between resources or a data access layer.

### Config
Environment-specific settings can be placed in the appropriate /config/environments/{environment}.rb file. These will get included automatically on a per-environment basis.

### Vendor
You can bake in gems using the bundler command `bundle install --deployment`. This will freeze the gem versions for use in deployment.

### Logs
Logs are created when running in production mode. In development, all logging goes to STDOUT.

## Testing
A simple testing framework, based on Ruby's TestUnit framework and rake, is available. The tests rely on a few conventions:

- Models and controllers should require and inherit from the /test/test_case.rb file (and TestCase class).
- Helpers should require and inherit from the /test/test_case_helpers.rb file (and TestCaseHelpers class).
- Libraries should have preferably have self-contained tests.

The [Rack::Test](http://www.sinatrarb.com/testing.html) environment is available from all test types for doing mock requests and reading responses.

### Rake tasks
Several rake tasks are available for running tests:

- `bundle exec rake test` runs all tests
- `bundle exec rake test:controllers` runs controller tests
- `bundle exec rake test:models` runs model tests
- `bundle exec rake test:helpers` runs helper tests

Tests can alternatively be run by invoking ruby directly:
`bundle exec ruby tests/controllers/test_hello_world.rb`\

## Logging
A global logger is provided, which unfortunately does not yet integrate with Sinatra's logger. The logger is available using the constant `LOGGER` and uses Apache's common logging format.

There are multiple levels of logging available (`debug`, `info`, `warn`, `error`, and `fatal`), with only logging for `info` and above available in the production environment.

For more information on the logger, see Ruby's [Logger class](http://www.ruby-doc.org/stdlib-1.9.3/libdoc/logger/rdoc/Logger.html).

## Bootstrapping
The application is bootstrapped from the app.rb file, which handles file load order, setting environment-wide configuration options, and makes controllers and helpers work properly in the Sinatra application without further work from the developer.

app.rb loads the /init.rb file to handle this process. Sinatra settings are included in the app.rb file.

## Dependencies
Dependent gems can be configured in the Gemfile using [Bundler](http://gembundler.com/).

## Appendix
The following is information you may find useful while working in a Ruby/Sinatra/Rack environment.

### Goo API Specifics
[Goo](https://github.com/ncbo/goo) is a general library for Object to RDF Mapping written by Manuel. It doesn't have any NCBO-specific pieces in it, except to model data in the way it makes sense for us. It includes functionality for basic CRUD operations.

Using Goo, we have created a library called [ontologies_linked_data](https://github.com/ncbo/ontologies_linked_data). This library extends Goo to provide specific models for use with NCBO data.

Eventually we hope to have some good documentation in code for the API, but while things are still in flux and time is short, you can see how things work by looking at the tests included with ontologies_linked_data or Goo. We'll cover the basics here:

#### Creating a new object
We can look at some tests in Goo to see how to work with objects built with Goo.

For example, here is an object `Person` defined in a test: [`test_model_person.rb`](https://github.com/ncbo/goo/blob/master/test/test_model_person.rb#L28-L40)

In the method `test_person`, you can see how an instance of the model is created: [`Person.new`](https://github.com/ncbo/goo/blob/master/test/test_model_person.rb#L49)

#### Validating an object

There can be restrictions on the kind of data stored in an attribute for a Goo object. For example, `Person` contains an attribute called `contact_data`. This attribute can only be populated with an instance of the `ContactData` class or it will not be considered valid. This is defined as a p[art of the object](https://github.com/ncbo/goo/blob/master/test/test_model_person.rb#L33) with this syntax:
`:contact_data , :instance_of => { :with => :contact_data }`

To test if an instance is valid, you can use the `valid?` method. For example:

    > p = Person.new
    > p.valid?
    => false

If calling `valid?` fails, the correspond errors will be available by calling the `errors` method, for example:

    > p = Person.new
    > p.valid?
    => false
    > p.errors

#### Saving an object
After validating an object, you can call the `save` method to store the object's triples in the triplestore backend. If the object isn't valid then calling `save` will result in an exception.

#### Retrieving an object
The simplest way to retrieve an object is using its id with the class method `find`:

`Person.find("paul")`

You can also do a lookup with the full id IRI:

`Person.find(RDF::IRI.new("http://example.org/person/paul"))`

Each object type has its own IRI prefix, so using the short form of the id will simply result it in being appended to the IRI prefix.

You can also search for objects using attribute conditions:

    Person.where(:name => "paul")
    Person.where(:birth_date => DateTime.parse("2012-10-04T07:00:00.000Z"))

You can also retrieve all objects:

`Person.all`

In the future, there will be syntax to handle [offsets and limits](https://github.com/ncbo/goo/issues/26).

#### Updating an object
After retrieving an object, you can modify attributes and then save the object in order to update the data. This corresponds to an HTTP PATCH.

Another option is to delete the existing object and write a new one with the same id as the old. This would be equivalent to an HTTP PUT.

#### Deleting an object
Goo objects also contain a `delete` method that will remove all of the object's triples from the store.

### Rack
[Rack](https://github.com/rack/rack) is a framework that sits between a web server (apache, passenger, thin, etc) and application code:

    [ web server ] → [ request ] → [ rack / middleware ] → [ application ]  ↓
                    [ web server ] ← [ response ] ← [ rack / middleware ] ←

Rack and its associated middleware basically wraps your application code and allows you to work with and modify the http request and response information. This happens in the `rack / middleware` steps above.

[Read More](http://whatcodecraves.com/articles/2012/07/23/ruby-on-rack)

## Acknowledgements

The National Center for Biomedical Ontology is one of the National Centers for Biomedical Computing supported by the NHGRI, the NHLBI, and the NIH Common Fund under grant U54-HG004028.

## License

[LICENSE.md](LICENSE.md)