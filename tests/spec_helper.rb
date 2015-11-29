# spec_helper.rb
# This example shows some site object code written for https://ruby-lang.org. The code here
# implements enough functionality to write some code to test news posts on the site.

require 'coveralls'
Coveralls.wear!

# save to CircleCI's artifacts directory if we're on CircleCI
require 'simplecov'
if ENV['CIRCLE_ARTIFACTS']
  dir = File.join(ENV['CIRCLE_ARTIFACTS'], "coverage")
  SimpleCov.coverage_dir(dir)
end

SimpleCov.start

require 'site-object'
require 'watir-webdriver'
require 'rspec'
# require 'rspec_junit_formatter'

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

# This is just a container class to store common features. The other classes below
# inherit this template to get the features. Because this class is defined as a
# page template there will be no accessor method for it on the site object.
class RubyLangTemplate < RubyLangSite::Page
  set_attributes :page_template # Page template, so no accessor method for this page
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

  def args_and_block(*args, &block)
    __method__
  end

  def args_only(*args)
    __method__
  end

  def block_only(&block)
    __method__
  end

  def method_only
    __method__
  end

end

# Models the news page, which shows summaries of the last ten most recent posts. The user
# can drill down on these summaries to read the full story.
class NewsPage < RubyLangTemplate
  # Sets a templated URL that will be used for navigation (and for URL matching if a URL
  # matcher isn't provided.) See HeaderBar and FooterBar page features defined above.
  set_url "/{language}/news/"
  set_url_matcher /\S+\/news\/$/

  # Returns all post summary divs with a little extra functionality wrapped around them.
  def posts
    @browser.divs(:class, 'post').map { |div| PostSummary.new(div) }
  end
end

# This page hosts a single, complete, news post. Users get to it by drilling down on
# summaries on the landing page or the news page.
class NewsPostPage < RubyLangTemplate
  set_url_matcher %r{/\S{2}/news/\d+/\d+/\d+/\S+/} #
  set_attributes  :navigation_disabled
  # use_features    :header_bar, :footer_bar

  element(:post) { |b| Post.new(b.div(:id, 'content-wrapper')) }
end

class AliasedFeature < PageFeature
  feature_name :aliased_feature_name
end

class TestingPage < RubyLangTemplate
  use_features :aliased_feature
  set_url "/{language}/"

  element(:foo) { |b| b.text_field(:id, 'bogus') }
end

class FooAttrPage < RubyLangTemplate
  set_url "/{language}/{foo}"
end

class NoAttrPage < RubyLangTemplate
  set_url "/en/"
end

class TestingPageNavDisabledOld < RubyLangTemplate
  disable_automatic_navigation
  set_url "/{language}/"
end

class TestingPageNavDisabledNew < RubyLangTemplate
  set_attributes :navigation_disabled
  set_url "/{language}/"
end

class TestingPageNoArgs < RubyLangTemplate
  set_url "/en/"
end

class TestingPageHasFrag < RubyLangTemplate
  set_url "/en/#/frag"
end

class TestingPageBadMatcher < RubyLangTemplate
  set_url_matcher /invalid/
end

class TestingPageFullURL < RubyLangTemplate
  set_url "https://rubygems.org"
  set_url_matcher /rubygems.org/
end

class BadSite
  include SiteObject
end

class BadPage < BadSite::Page
  set_url_matcher 'invalid'
end

class EmptySite
  include SiteObject
end

class GoogleSite
  include SiteObject
end

class GithubSite
  include SiteObject
end

class ExplorePage < GithubSite::Page
  set_url '/explore'
end

class TestingPageEmptyURL < GithubSite::Page
  set_url ''
end

class Lang
  attr_accessor :language

  def initialize(language)
    @language = language
  end
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
