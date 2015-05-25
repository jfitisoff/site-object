# site-object
Wraps page objects up into a site object, which provides some introspection and navigation capabilities page objects don't provide. Works with Watir and Selenium.

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
methods that you can use to open or close a browser after initialization:

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
  # If this is a relative URL then it'll be appended to the base_url defined when site is initialized.
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
```

A few notes about the page object code example: 

The set_url method is used to define a template for the page's URL. It can
be a partial or full URL, or you can omit it entirely, in which case the page's URL will be the same as the
base_url. The URL defined here is used to create a URL template, which gets utilized for both navigation 
and to determine if the page is being displayed. Templates can be defined with dynamic values that can 
change at runtime. For more info, see the Page.set_url method in the documentation.

Element definitions take two arguments: an element method name and a block defining how the element is accessed.
The block argument 'b' is a browser/driver object that gets passed down to the element from the page it's
getting accessed from. In the example, Watir is getting used but you could used Selenium here too. 
There's no abstraction layer between the page object library and Selenium/Watir -- you work directly with
the underlying browser library and have access to everything that Watir or Selenium can do.

Note that the login method utilizes the page elements defined earlier.

When defining a page object you have access to the browser as well. It's not shown in the example above but
you can access it via @browser.

Page Features
===============

Page features are used to model things that are present on multiple pages. For example, you'll often
see a common footer used across corporate websites with links to About, Careers and News pages. Here's
how the footer could be implemented via a page feature:

```ruby
class Footer < PageFeature
  element(:about) { |b| b.div(:id, 'footer').link(:text, 'About') }
  element(:about) { |b| b.div(:id, 'footer').link(:text, 'Careers') }
  element(:about) { |b| b.div(:id, 'footer').link(:text, 'News') }
  element(:about) { |b| b.div(:id, 'footer').link(:text, 'Contact') }
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

This is an experimental feature that may or may not be useful to you (it's designed with Watir in mind.) 
The idea is to provide a wrapper around the element that will allow you to add some features that the 
underlying element may not provide. See code examples below.


RSpec Example:
===============

The following test example uses rspec and watir-webdriver and was tested with Firefox, which watir-webdriver
and selenium-webdriver support out of the box because the Firefox webdriver implementation doesn't require
a driver library.  

spec_helper.rb
```ruby
# spec_helper.rb
# This example shows some site object code written for https://ruby-lang.org. The code here 
#implements enough functionality to write some code to test news posts on the site.
require 'site-object'
require 'watir-webdriver'
require 'rspec'

# The site object for ruby-lang.org.
class RubyLangSite
  attr_accessor :language 
  include SiteObject
  
  def initialize(base_url:, browser:, language:) # Mandatory keyword arguments, new in Ruby 2.1.x.
    @language = language                         # Set the attr_accessor defined for thse class.
    super base_url: base_url, browser: browser   # Finish initialization, passing along the mandatory site object arguments.
  end
end

# A page feature. This one models the header bar with links that runs across the top of all of the 
# site's pages. It can be added to a page object by calling the use_features method when defining a 
# page's class. When added to a page class, the initialized page has an accessor method for it (see 
# usage below.)
class HeaderBar < PageFeature
  ['downloads', 'documentation', 'libraries', 'community', 'news', 'security', 'about'].each do |lnk|
    element(lnk) { |b| b.div(:id, 'header_content').a(href: /\/#{lnk}/) }
  end
end

# A page feature. This one models the footer bar with links that runs across the bottom of all of 
# the site's pages. It can be added to a page object by calling the use_features method when 
# defining a page's class. When added to a page class, the initialized page has an accessor method 
# for it (see usage below.)
class FooterBar < PageFeature
  ['downloads', 'documentation', 'libraries', 'community', 'news', 'security', 'about'].each do |lnk|
    element(lnk) { |b| b.div(:id, 'footer').a(href: /\/#{lnk}/) }
  end
end

# Models the page that users first see when they access the site. The landing page will display 
# summaries of the four most recent news posts. You can click on these summaries to drill down to a 
# page that contains the complete news post. The landing page also has links to navigate to the news 
# page, which has a larger selection of news posts (the last ten most recent posts.)
class LandingPage < RubyLangSite::Page
  set_url "/{language}/"  # Sets a templated URL that will be used for navigation (and for URL matching if a URL matcher isn't provided.)
  use_features :header_bar, :footer_bar  # See HeaderBar and FooterBar page features defined above.  

  # Create a method that takes all of the landing page post divs and wrap some more functionality around them.
  def posts
    @browser.divs(:class, 'post').map { |div| PostSummary.new(div) } # See PostSummary class above. 
  end
end

# Models the new page, which shows summaries of the last ten most recent posts. The user can drill 
# down on these summaries to read the full story. 
class NewsPage < RubyLangSite::Page
  set_url "/{language}/news/" # Sets a templated URL that will be used for navigation (and for URL matching if a URL matcher isn't provided.)
  use_features :header_bar, :footer_bar  # See HeaderBar and FooterBar page features defined above. 

  # Returns all of the post summary divs with a little extra functionality wrapped around them.
  def posts
    @browser.divs(:class, 'post').map { |div| PostSummary.new(div) } # See PostSummary class above.
  end
end

# This page hosts a single, complete, news post. Users get to it by drilling down on sumaries on 
# the landing page or the news page.
class NewsPostPage < RubyLangSite::Page
  set_url_matcher  %r{/en/news/\d+/\d+/\d+/\S+/} #
  disable_automatic_navigation
  use_features :header_bar, :footer_bar  # See HeaderBar and FooterBar page features defined above. 

  element(:post) { |b| Post.new(b.div(:id, 'content-wrapper')) }
end

# An element container class. This class adds a little bit of functionality to the underlying 
# element.
class Post < ElementContainer
  def post_title
    links[0]
  end
  
  def post_info
    p(:class, 'post-info')
  end
end

# An element container class. This class adds a little bit of functionality to the Post class it 
# inherits from.
class PostSummary < Post

  def continue_reading
    links.last
  end

end
```

landing_page.rb
```ruby
# Some RSpec tests that check out the news post functionality of the https://ruby-lang.org site.
require_relative 'spec_helper'

describe "https://ruby-lang.org" do
  
  before(:all) do
    @site = RubyLangSite.new(
      base_url: "https://www.ruby-lang.org", 
      browser: Watir::Browser.new,
      language: "en"
    )
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
      landing_page_title = @site.landing_page.posts[0].post_title.text
      @site.landing_page.posts[0].continue_reading.click
      expect(@site.page).to be_instance_of NewsPostPage
    end

  end

end
```

pry and irb 
===============

```ruby
# Load site-object and watir-webdriver.
require 'site-object'
require 'watir-webdriver'

# Create a site object. Watir will try to load Firefox. If you don't have Firefox installed you can 
# substitute another browser if you have installed the driver for it.
site = RubyLangSite.new(base_url: "https://www.ruby-lang.org", browser: Watir::Browser.new, language: "en")

# Load the landing page. Since you've just created the site object you haven't navigated to any 
# page yet. The site object figures this out by looking at the browser URL and automatically loads 
# the page. The method call will return a LandingPage object.
site.landing_page

# Get the landing page again. No navigation occurs this time because the site object sees that it's 
# already on the landing page.
site.landing_page

# Drill down to the news page from the landing page by clicking on the link to the news page in the 
# landing page's footer bar.
site.landing_page.footer_bar.news.click

# You're now on the news page. The site object knows about this. You can confirm that by asking for
# the current page. The new page has been defined for the site so the site object will look through
# all of its pages, determine that it's on the news page and then return a page object for it.
site.page

# The news page will display the 10 most recent Ruby posts from the news feed. Ask the site how many
# posts are on the page:
site.page.posts.length

# If the site object sees a method it doesn't recognize it delegates the method to the current page, 
# if it recognizes it. So it's often possible to avoid explicit calls to pages if you want to do 
# that.
site.landing_page # Go to the landing page unless you're already on it.
site.landing_page.posts.length # Should return 4.
site.header_bar.news.click # Method call gets delegated to the landing page and the click navigates you to the news page.
site.page # You should get a news page object back here since you should be on the news page.
site.posts.length # Should return 10 since the news page normally displays 10 summaries.
site.posts[0].title.text # Get the title text of the most recent post.
site.posts[0].continue_reading.click # Drill down on the most recent post.
site.page # You should now be on the page that displays a full post (NewsPostPage.)
```


