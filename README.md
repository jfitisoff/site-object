# site-object
[![Gem Version](https://badge.fury.io/rb/site-object.svg)](https://rubygems.org/gems/site-object)
[![Build Status](https://circleci.com/gh/jfitisoff/site-object.svg?style=shield)](https://circleci.com/gh/jfitisoff/site-object)
[![Coverage Status](https://coveralls.io/repos/jfitisoff/site-object/badge.svg?nocache)](https://coveralls.io/r/jfitisoff/site-object)

Wraps page objects up into a site object, which provides some introspection and
navigation capabilities page objects don't provide. Works with Watir and Selenium.

Features
===============
##Easily Handle Multiple Test Environments
One pretty common problem for testers is writing automation that can be applied against
multiple development environments. Site objects allow you to set a base URL when
initializing a site and then specify relative URLs for all of your pages. This allows
you to define a different base URL at runtime based on the environment you want to
run your tests against. You can also override the base URL on a per page basis if you
need to.

##Simpler Page Object Initialization and Navigation
Your browser library (Watir or Selenium) gets initialized at the site level. The site
object stores a browser reference and automatically passes it down to a page object
as it gets initialized. So there's no need to feed a page object a browser object every
time you need a page.

Site objects automatically define accessor methods for every page object that you create.
When you call an accessor method it handles navigation automatically. If you're not
currently on the page you're calling it will automatically navigate to the page before
returning the page object. If you *are* on the page already it'll just return a page object
for the page without doing any navigation.

This reduces the amount of code that you have to write to get a page. Typically, most
page object frameworks have you do it something like this:

```ruby
page = MyPage.new(browser)
page.visit
```

Here's the equivalent site object code:

```ruby
site.my_page  # Page is loaded automatically if it's not getting displayed.
```

*Note 1:* There's also an additional helper method that gets created for each page object,
which allows you to check whether or not it's being displayed in the browser.

```ruby
site.my_page? # Additional helper method created for each page class.
=> true
```

*Note 2:* If you want to, you can disable automatic navigation by including the
disable_automatic_navigation method when defining a page object class (see example
below.)

##Templated URLs and Support for Object Arguments
All URLs for page objects are defined using URL templates. For example, if you have an
account details page that requires an account code you can define a page object that looks
like this:

```ruby
class AccountDetailsPage < MySite::Page
  set_url "/accounts/{account_code}" # Used for navigation and page matching (but see below.)
end
```

And then you can use the page object in the following manner, providing a hash to fill in
the templated values:

```ruby
site.account_details_page account_code: '5233543656575767'
```

Even better, if you have a Ruby object that responds to "account_code" you can just use
that. The page object will try to get the page arguments it needs from the account
object when it's initialized:

```ruby
site.account_details_page account
```

In the example above, the account argument can be anything as long as it has an
account_code method.

*Note:* Regardless of whether you are using a hash or some other object to initialize
a page, if the object doesn't respond to an argument required by the templated URL
the page object will fall back to looking at the arguments used to initialize the site
object. If it sees a match there it will use that argument to fill in the gaps when
attempting to initialize the page. This allows you to specify things like a subdomain
or a port number when initializing the site object and use them when defining URL
templates for your page objects.

##Overriding a URL Template for Navigation Purposes
For cases where the URL template may not be sufficient to match the final URL that's
displayed, you can define a regular expression that overrides the template when the site
object is looking at the browser URL to determine whether or not it's on a particular
page:

```ruby
class AccountDetailsPage < MySite::Page
  set_url "/accounts/{account_code}" # This will be used for all navigation.
  set_url_matcher %r{/accounts/\d+$} # This will be used for all page matching.
end

```

##Page Templates
Web applications typically have recurring bits of functionality that you'll see on
many pages. For example, most web applications have a logout link that's accessible
from every page when you are logged in. The site-object library allows you to
define a page object that can serve as a container for common features like that
logout link. You can then create other pages that inherit from your page feature
class and get the common features that are defined in your template:

```ruby
# Set up a page object as a template using the set_attributes method:
class SomeTemplate
  set_attributes :page_template # This makes this page class a template.

  el(:logout) { |b| b.link(:id, 'logout') } # Accessor method for Logout link.
end

# Create another page object that inherits from your template:
class SomePage < SomeTemplate
  # Page-specific code here...
end

# Then, once a site object has been initialized you can use the logout link from
# the page that inherits from the page template:
site.some_page.logout.click

# The page template itself won't be accessible though. No accessor method is created
# for it on the site object (because it's a template for other pages.):
site.some_template
NoMethodError: undefined method `some_template' for #<SomeSite:0x007f9550d24d98>

# And if you ask a site about its pages the page object template won't be included:
site.pages
=> [SomePage, SomeOtherPage, YetAnotherPage] # Template page not included.
```

##Introspection
The site object knows about all of its pages and can tell what page it's on by looking
at the URL that the browser's displaying:

```ruby
site.page
=> <SomePage>
```

If the site object can't find a matching page for the URL then it will return nil:

```ruby
site.page
=> nil
```

The site object takes this ability to identify the page that it's currently on one step
further. If it gets a method call it doesn't recognize then it delegates the method
call down to the page that it's currently on. This is really useful when dealing with
multi-page workflows and makes the page objects themselves a lot less important:

```ruby
site.account_details_page account # Where account is an object that responds to account_code (see above.)
site.edit_account.click # Method call is delegated to the account details page object.
site.edit_account first_name: 'Bob' # Method call is delegated to the account edit page object.
site.page # After the edit is completed the details page gets loaded again.
=> <AccountDetailsPage>
```

Defining and Instantiating a Site Object
===============

```ruby
require 'site-object'

class MySite
  include SiteObject
end

site = MySite.new(base_url: "http://mysite.org", browser: browser_obj)
```

In the example above, the browser argument is optional. The site object also has open_browser and close_browser
methods that you can use to open or close a browser after a site object has been initialized:

```ruby
site = MySite.new(base_url: "http://mysite.org")
site.open_browser(:selenium, :firefox, profile: "some-profile")

site.some_page # Page navigation is automatic if the page isn't already being displayed.
```

Defining and Using Page Objects
===============

```ruby
# When the SiteObject module is imported it automatically creates a Page class underneath the
# site object. You'll inherit from this class when defining pages for the site.
class MySite
  include SiteObject
end

# New page class inherits from the site's Page class (see above.)
class LoginPage < MySite::Page
  # If this is a relative URL then it'll be appended to the base_url defined when the site is
  # initialized.
  set_url "/login"

  # Page element definitions. # The text_field and button methods below are Watir methods but
  # Selenium could be used here too.
  element(:user_name) { |b| b.text_field(:id, 'user_name') }
  element(:password)  { |b| b.text_field(:id, 'password') }
  element(:login)     { |b| b.button(:name, 'Login') }

  # Higher-level method that uses all of the page elements to implement login.
  def login(user, pwd)
    user_name.set user
    password.set pwd
    login.click
  end
end

# After the new site object is initialized it will have a login_page accessor method for the
# LoginPage class.
site = MySite.new(base_url: "http://mysite.org", browser: Watir::Browser.new)
site.login_page # Nav to login and return a LoginPage object.

```

A few notes about the page object code example:

The set_url method is used to define a template for the page's URL. It can be a partial or full
URL, or you can omit it entirely, in which case the page's URL will be the same as the base_url.
The URL defined here is used to create a URL template, which gets utilized for both navigation
and to determine if the page is being displayed. Templates can be defined with dynamic values
that can change at runtime. For more info, see the Page.set_url method in the documentation.

Element definitions take two arguments: an element method name and a block defining how the
element is accessed.The block argument 'b' is a browser/driver object that gets passed down to
the element from the page it's getting accessed from. In the example, Watir is getting used but
you could used Selenium here too. There's no abstraction layer between the page object library
and Selenium/Watir -- you work directly with the underlying browser library and have access to
everything that Watir or Selenium can do.

Note that the login method utilizes the page elements defined earlier.

When defining a page object you have access to the browser as well. It's not shown in the
example above but you can access it via @browser.

Page Features
===============

Page features are used to model things that are present on multiple pages. For example, you'll
often see a common footer used across corporate websites with links to About, Careers and News
pages. Here's how the footer could be implemented via a page feature:

```ruby
class Footer < PageFeature
  element(:about)   { |b| b.div(:id, 'footer').link(:text, 'About') }
  element(:careers) { |b| b.div(:id, 'footer').link(:text, 'Careers') }
  element(:news)    { |b| b.div(:id, 'footer').link(:text, 'News') }
  element(:contact) { |b| b.div(:id, 'footer').link(:text, 'Contact') }
end

class MyPage < MySite::Page
  set_url "/my/url/fragment"
  use_features :footer
end
```

Then, to access:

```ruby
site.my_page.footer.about.click
```

Element Containers
===============

This is an experimental feature that may or may not be useful to you (it's designed with Watir
in mind.) The idea is to provide a wrapper around the element that will allow you to add some
features that the underlying element may not provide. See code examples below.


RSpec Example:
===============

The following test example uses rspec and watir-webdriver and was tested with Firefox, which
watir-webdriver and selenium-webdriver support out of the box because the Firefox webdriver
implementation doesn't require a driver library.  

```ruby
# spec_helper.rb
# This example shows some site object code written for https://ruby-lang.org. The code here
# implements enough functionality to write some code to test news posts on the site.
require 'site-object'
require 'watir-webdriver'
require 'rspec'

# The site object for ruby-lang.org.
class RubyLangSite
  attr_accessor :language
  include SiteObject

  def initialize(browser, language)
    @language = language  # Set the attr_accessor defined for this class.
    super base_url: "https://www.ruby-lang.org", browser: browser # Finish initialization.
  end
end

# A page feature. This one models the header bar with links that runs across the top of all
# of the site's pages. It can be added to a page object by calling the use_features method
# when defining a page's class. When added to a page class, the initialized page has an
# accessor method for it (see usage below.)
class HeaderBar < PageFeature
  ['downloads', 'documentation', 'libraries',
   'community', 'news', 'security', 'about'].each do |lnk|
    element(lnk) { |b| b.div(:id, 'header_content').a(href: /\/#{lnk}/) }
  end
end

# A page feature. This one models the footer bar with links that runs across the bottom of
# all of the site's pages. It can be added to a page object by calling the use_features
# method when defining a page's class. When added to a page class, the initialized page has
# an accessor method for it (see usage below.)
class FooterBar < PageFeature
  ['downloads', 'documentation', 'libraries',
   'community', 'news', 'security', 'about'].each do |lnk|
    element(lnk) { |b| b.div(:id, 'footer').a(href: /\/#{lnk}/) }
  end
end

class RubyLangTemplate < RubyLangSite::Page
  set_attributes :page_template
  use_features   :header_bar, :footer_bar # See HeaderBar and FooterBar defined above.
end

# Models the page that users first see when they access the site. The landing page will
# display summaries of the four most recent news posts. You can click on these summaries to
# drill down to a page that contains the complete news post. The landing page also has links
# to navigate to the news page, which has a larger selection of news posts (the last ten
# most recent posts.)
class LandingPage < RubyLangTemplate
  # Sets a templated URL that will be used for navigation (and for URL matching if a URL
  # matcher isn't provided.)
  set_url "/{language}/"
  # use_features :header_bar, :footer_bar # See HeaderBar and FooterBar defined above.

  # Create a method that takes all of the landing page post divs and wrap some more
  # functionality around them. Also see PostSummary class above.
  def posts
    @browser.divs(:class, 'post').map { |div| PostSummary.new(div) }
  end
end

# Models the news page, which shows summaries of the last ten most recent posts. The user
# can drill down on these summaries to read the full story.
class NewsPage < RubyLangTemplate
  # Sets a templated URL that will be used for navigation (and for URL matching if a URL
  # matcher isn't provided.) See HeaderBar and FooterBar page features defined above.
  set_url "/{language}/news/"
  # use_features :header_bar, :footer_bar

  # Returns all post summary divs with a little extra functionality wrapped around them.
  def posts
    @browser.divs(:class, 'post').map { |div| PostSummary.new(div) }
  end
end

# This page hosts a single, complete, news post. Users get to it by drilling down on
# summaries on the landing page or the news page.
class NewsPostPage < RubyLangTemplate
  set_url_matcher %r{/en/news/\d+/\d+/\d+/\S+/} #
  set_attributes  :navigation_disabled
  # use_features    :header_bar, :footer_bar

  element(:post) { |b| Post.new(b.div(:id, 'content-wrapper')) }
end

# An element container class. This class adds a little bit of functionality to the
# underlying element.
class Post < ElementContainer
  def post_title
    links[0]
  end

  def post_info
    p(:class, 'post-info')
  end
end

# An element container class. This class adds a little bit of functionality to the Post
# class it inherits from.
class PostSummary < Post

  def continue_reading
    links.last
  end
end
```

```ruby
# landing_page_tests.rb
# Some RSpec tests for the news post functionality of the https://ruby-lang.org site.
require_relative 'spec_helper'

describe "https://ruby-lang.org" do

  before(:all) do
    @site = RubyLangSite.new(Watir::Browser.new, "en")
  end

  describe "Landing Page:" do

    it "shows 4 news posts on the landing page" do
      expect(@site.landing_page.posts.length).to eq 4
    end

    it "has a link to the News page in the header bar links" do
      @site.landing_page.header_bar.news.present?
    end

    it "drills down to the News page via the header bar" do
      @site.landing_page.header_bar.news.click
      expect(@site.page).to be_instance_of NewsPage
    end

    it "has a link to the News page in the footer bar links" do
      @site.landing_page.footer_bar.news.present?
    end

    it "drills down to the News page via the footer bar" do
      @site.landing_page.footer_bar.news.click
      expect(@site.page).to be_instance_of NewsPage
    end

    it "has same title for most recent post as the news page does" do
      landing_page_title = @site.landing_page.posts[0].post_title.text
      news_page_title    = @site.news_page.posts[0].post_title.text
      expect(landing_page_title).to eq news_page_title
    end

    it "drills down on the most recent post summary" do
      @site.landing_page.posts[0].continue_reading.click
      expect(@site.page).to be_instance_of NewsPostPage
    end

  end

end
```

pry and irb
===============

```ruby
# Note: The commands shown here rely on the sample code shown above for
# https://ruby-lang.org. You'll need get that code in your pry or irb session for these
# examples to work.

# Load site-object and watir-webdriver.
require 'site-object'
require 'watir-webdriver'

# Create a site object. Watir will try to load Firefox. If you don't have Firefox installed
# you can substitute another browser if you have installed the driver for it. If a failure
# occurs here it's likely for that reason.
#
# Site objects typically take a hash of values but the init routine was modified for
# this one, see above.
site = RubyLangSite.new(Watir::Browser.new, "en")

# Load the landing page. Since you've just created the site object you haven't navigated to
# any page yet. The site object figures this out by looking at the browser URL and
# automatically loads the page. The method call will return a LandingPage object.
site.landing_page

# Get the landing page again. No navigation occurs this time because the site object sees
# that it's already on the landing page.
site.landing_page

# Drill down to the news page from the landing page by clicking on the link to the news page
# in the landing page's footer bar.
site.landing_page.footer_bar.news.click

# You're now on the news page. The site object knows about this. You can confirm that by
# asking for the current page. The new page has been defined for the site so the site object
# will look through all of its pages, determine that it's on the news page and then return
# a page object for it.
site.page

# The news page will display the 10 most recent Ruby posts from the news feed. Ask the site
# how many posts are on the page:
site.page.posts.length

# If the site object sees a method it doesn't recognize it delegates the method to the
# current page, if it recognizes it. So it's often possible to avoid explicit calls to pages
# if you want to do that.
site.landing_page # Go to the landing page unless you're already on it.
site.landing_page.posts.length # Should return 4.
site.header_bar.news.click # Method call gets delegated to the landing page.
site.page # You should get a news page object back here since you should be on the news page.
site.posts.length # Should return 10 since the news page normally displays 10 summaries.
site.posts[0].post_title.text # Get the title text of the most recent post.
site.posts[0].continue_reading.click # Drill down on the most recent post.
site.page # You should now be on the page that displays a full post (NewsPostPage.)
```
