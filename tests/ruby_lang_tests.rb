# landing_page_tests.rb
# Some RSpec tests for the news post functionality of the https://ruby-lang.org site.
require_relative 'spec_helper'

describe "https://ruby-lang.org" do

  before(:all) do
    @site = RubyLangSite.new(Watir::Browser.new, "en")
  end

  after(:all) do
    @site.browser.close
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

describe "site-object" do

  describe "Page Feature" do

    before(:all) do
      @site = RubyLangSite.new(Watir::Browser.new, "en")
    end

    after(:all) do
      @site.browser.close
    end

    it "creates a feature with an aliased name when a :feature_name is defined" do
      expect(@site.testing_page).to respond_to :aliased_feature_name
    end

  end

end
# Initial stab at getting code coverage to 100%. Just doing the bare minimum right
# now, know that the code isn't organized the way you'd want to ti be. That'll
# come later.
describe "Page Object" do

  before(:all) do
    @github = GithubSite.new(
      base_url: 'https://github.com/',
      browser:  Watir::Browser.new
    )

    @site = RubyLangSite.new(Watir::Browser.new, "en")
  end

  before(:each) do
    @site.language = 'en' # Because one test overrides the value set at init.
  end

  after(:all) do
    @site.close_browser
    @github.close_browser
  end

  it "disables automatic navigation the old way" do
    @site.news_page
    expect { @site.testing_page_nav_disabled_old }.to raise_error SiteObject::PageNavigationNotAllowedError
  end

  it "raises a PageConfigError when an invalid page attribute is defined" do
    klass = Class.new(RubyLangSite::Page)
    expect { klass.send(:set_attributes, :bar) }.to raise_error SiteObject::PageConfigError
  end

  it "overrides the base_url when the page URL is fully qualified" do
    klass = Class.new(RubyLangSite::Page)
    klass.send(:set_url, "https://google.com")
    expect(klass.page_url).to eq "https://google.com"
  end

  it "raises a PageInitError when no args are provided for page with required argument" do
    @site.language = nil
    expect { @site.foo_attr_page }.to raise_error SiteObject::PageInitError
  end

  it "raises a PageInitError when hash args don't include required param" do
    @site.language = nil
    expect { @site.foo_attr_page wrong: 'argument' }.to raise_error SiteObject::PageInitError
  end

  it "raises a PageInitError when object arg doesn't respond to required param" do
    @site.language = nil
    expect { @site.foo_attr_page 'whoops' }.to raise_error SiteObject::PageInitError
  end

  it "supports a custom inspect method" do
    expect(@site.landing_page.inspect.length).to be < 130
  end

  it "can tell it's on the page when there are no page args" do
    expect(@site.testing_page_no_args.on_page?).to be_truthy
  end

  it "uses URL fragment for a page url template that specifies one" do
    expect(@site.testing_page_has_frag.page_url).to match %r{/en/#/frag$}
  end

  it "strips out a URL fragment when doing matching for a page url template that doesn't specify one" do
    @site.landing_page
    @site.browser.goto @site.browser.url + "/#/foo"
    expect(@site.landing_page).to be_on_page
  end

  it "visits a page" do
    expect(@site.landing_page.visit.browser.text).to match /A Programmer's Best Friend/i
  end

  it "refreshes a page" do
    expect(@site.landing_page.refresh.browser.text).to match /A Programmer's Best Friend/i
  end

  it "raises an error when a page matcher doesn't match when the page is visited" do
    expect { @site.testing_page_bad_matcher.visit }.to raise_error SiteObject::WrongPageError
  end

  it "won't use an unsupported browser library" do
    p = @site.landing_page
    p.instance_variable_set :@browser, 'invalid'
    expect { p.visit }.to raise_error SiteObject::BrowserLibraryNotSupportedError
  end

  it "doesn't raise when expect_page is called and current page matches" do
   p = @site.landing_page
   expect(@site.expect_page(LandingPage)).to be_truthy
   expect(@site.expect_page(p)).to be_truthy
   expect(@site.expect_page(:landing_page)).to be_truthy
  end

  it "raises when expect_page is called and current page is known but does not match" do
    @site.news_page
    expect { @site.expect_page(LandingPage) }.to raise_error SiteObject::WrongPageError
  end

  it "raises when expect_page is called and current page unknown" do
    @site.browser.goto('https://google.com')
    expect { @site.expect_page(LandingPage) }.to raise_error SiteObject::WrongPageError
  end

  it "won't initialize a site object if the argument isn't a Hash" do
    expect { EmptySite.new 'invalid' }.to raise_error SiteObject::SiteInitError
  end

  it "won't initialize a site object if a non-regexp page matcher is defined" do
    expect { BadSite.new {} }.to raise_error SiteObject::PageConfigError
  end

  it "defines a ? method to verify page display" do
    @site.landing_page
    expect(@site.landing_page?).to be_truthy
    expect(@site.news_page?).to be_falsey
  end

  it "defines a custom inspect method" do
    expect { @site.inspect }.to_not raise_error
  end

  it "calls a page element" do
    @site.news_page.posts.first.post_title.click
    expect(@site.news_post_page?).to be_truthy
    expect(@site.post.text).to be_kind_of(String)
  end

  it "handles an empty page_url" do
    @github.testing_page_empty_url
    expect(@github.testing_page_empty_url?).to be_truthy
  end

  it "handles a fully qualified page_url" do
    @site.testing_page_full_url
    expect(@site.testing_page_full_url?).to be_truthy
  end

  it "can be initialized with a non hash argument" do
    lang = Lang.new('en')
    @site.landing_page lang
  end

  it "raises when the page URL has no arguments but page arguments are provided" do
    expect { @site.no_attr_page foo: 'bar' }.to raise_error SiteObject::PageInitError
  end

end

describe "Site Object Delegation" do

  before(:all) do
    @site = RubyLangSite.new(Watir::Browser.new, "en")
  end

  after(:all) do
    @site.close_browser
  end

  context "Delegation to Most Recent Page" do
    before(:each) { @site.landing_page.visit }

    it "delegates unknown method with args and block down to most recent page" do
      expect(@site.args_and_block(1, 2) {'foo'}).to eq :args_and_block
    end

    it "delegates unknown method with block down to most recent page" do
      expect(@site.block_only {'foo'}).to eq :block_only
    end

    it "delegates unknown method with args down to most recent page" do
      expect(@site.args_only(1, 2)).to eq :args_only
    end

    it "delegates unknown method with no args or block down to most recent page" do
      expect(@site.method_only).to eq :method_only
    end

    it "hits method_missing when the page doesn't recognize delegated method" do
      expect { @site.invalid_method_call }.to raise_error NoMethodError
    end
  end

  context "Delegation after Finding Page" do
    before(:each) do
      @site.news_page.visit
      @site.browser.goto @site.base_url + '/en/'
    end

    it "delegates unknown method with args and block after it identifies new page" do
      expect(@site.args_and_block(1, 2) {'foo'}).to eq :args_and_block
    end

    it "delegates unknown method with block after it identifies new page" do
      expect(@site.block_only {'foo'}).to eq :block_only
    end

    it "delegates unknown method with args after it identifies new page" do
      expect(@site.args_only(1, 2)).to eq :args_only
    end

    it "delegates unknown method after it identifies new page" do
      expect(@site.method_only).to eq :method_only
    end

    it "hits method_missing when the page doesn't recognize delegated method" do
      expect { @site.invalid_method_call }.to raise_error NoMethodError
    end
  end

end

describe "Site Object Browser Management" do

  context "Watir" do
    before(:all) do
      @site = GoogleSite.new(base_url: 'https://google.com')
    end

    it "opens a browser" do
      @site.open_browser(:watir, :firefox)
      expect(@site.browser).to be_instance_of Watir::Browser
    end

    it "closes a browser" do
      @site.browser.close
      expect(@site.browser.exists?).to be_falsey
    end
  end

  context "Selenium" do
   before(:all) do
     @site = GoogleSite.new(base_url: 'https://google.com')
   end

   it "opens a browser" do
     @site.open_browser(:selenium, :firefox)
     expect(@site.browser).to be_instance_of Selenium::WebDriver::Driver
   end

   it "closes a browser" do
     expect { @site.browser.close }.to_not raise_error
   end
 end
end
