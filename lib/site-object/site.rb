# Usage:
#  require 'site-object'
#  class MySite
#    include SiteObject
#  end
module SiteObject
  attr_reader :base_url, :unique_methods
  attr_accessor :pages, :browser, :arguments, :most_recent_page

  # Sets up a Page class when the SiteObject module is included in the class you're using to model
  # your site.
  def self.included(base)
    klass = Class.new
    base.const_set('Page', klass)
    base::Page.send(:extend,  PageObject::PageClassMethods)
    base::Page.send(:include, PageObject::PageInstanceMethods)
  end

  # Closes the site object's browser
  def close_browser
    @browser.close # Same for watir-webdriver and selenium-webdriver.
  end

  # Helper method designed to assist with complex workflows. Basically, if you're navigating and
  # expect a certain page to be displayed you can use this method to confirm that the page you want is
  # displayed and then get a page object for it.
  #
  # This method just checks to see if the right class of page is being displayed. If you have defined
  # a templated value in the URL of the page object getting checked it doesn't check the values of
  # the arguments. It only confirms whether or not the arguments are present.
  def expect_page(page_arg)
    p = page

    if p
      if p.class.name == page_arg.class.name  # Do this if it looks like an instance of a page.
        return p
      elsif p.class == page_arg               # Do this if it looks like a page class name.
        return p
      elsif page_arg.is_a?(Symbol) && p.class.name.underscore.to_sym == page_arg
        return p
      else
        raise SiteObject::WrongPageError, "Expected #{page_arg} page to be displayed but the URL doesn't look right. \n\n#{caller.join("\n")}"
      end
    else
      raise SiteObject::WrongPageError, "Expected #{page_arg} page to be displayed but the URL doesn't appear to match the URL template of any known page. \n\n#{caller.join("\n")}"
    end
  end

  # Creates a site object, which will have accessor methods for all pages that have been defined for
  # the site. This object takes a hash argument. There is only one required value (the base_url for
  # the site.) Example:
  #
  #  class MySite
  #    include SiteObject
  #  end
  #
  #  site = MySite.new(base_url: "http://foo.com")
  #
  # You can also specify any other arguments that you want for later use:
  #
  #  site = MySite.new(
  #    base_url: "http://foo.com",
  #    foo:      true
  #    bar:      1
  #  )
  #  site.foo
  #  => true
  #  site.bar
  #  => 1
  def initialize(args={})
    unless args.is_a?(Hash)
      raise SiteObject::SiteInitError, "You must provide hash arguments when initializing a site object. At a minimum you must specify a base_url. Example:\ns = SiteObject.new(base_url: 'http://foo.com')"
    end

    @arguments   = args.with_indifferent_access
    @base_url    = @arguments[:base_url]
    @browser     = @arguments[:browser]
    @pages       = self.class::Page.descendants.reject { |p| p.page_template? }

    # Set up accessor methods for each page and page checking methods..
    @pages.each do |current_page|
      unless current_page.page_template?
        current_page.set_url_template(@base_url)

        if current_page.url_matcher
          unless current_page.url_matcher.is_a? Regexp
            raise SiteObject::PageConfigError, "A url_matcher was defined for the #{current_page} page but it was not a regular expression. Check the value provided to the set_url_matcher method in the class definition for this page. Object provided was a #{current_page.url_matcher.class.name}"
          end
        end

        self.class.class_eval do
          define_method(current_page.to_s.underscore) do |args=nil, block=nil|
            current_page.new(self, args)
          end

          define_method("#{current_page.to_s.underscore}?") do
            on_page? current_page
          end
        end
      end
    end

    visited = Set.new
    tmp = @pages.map {|p| p.instance_methods }.flatten
    tmp.each do |element|
      if visited.include?(element)
       else
        visited << element
      end
    end
    @unique_methods = visited
  end

  # Custom inspect method so that console output doesn't get in the way when debugging.
  def inspect
    "#<#{self.class.name}:0x#{object_id}\n @base_url=\"#{@base_url}\"\n @most_recent_page=#{@most_recent_page}>"
  end

  # In cases where the site object doesn't recognize a method it will try to delegate the method call
  # to the page that's currently being displayed in the browser, assuming that the site object recognizes
  # the page by its URL. If the page is the last visited page and method is unique, (i.e., doesn't belong
  # to any other page object) then the site object won't attempt to regenerate the page when calling
  # the method.
  def method_missing(sym, *args, &block)
    if @unique_methods.include?(sym) && @most_recent_page.respond_to?(sym)
      if args && block
        @most_recent_page.send(sym, *args, &block)
      elsif args
        @most_recent_page.send(sym, *args)
      elsif block
        @most_recent_page.send(sym, &block)
      else
        @most_recent_page.send sym
      end
    elsif p = page
      if p.respond_to?(sym)
        if args && block
           p.send(sym, *args, &block)
        elsif args
          p.send(sym, *args)
        elsif block
          p.send(sym, &block)
        else
          p.send sym
        end
      else
        super
      end
    else
      super
    end
  end

  # Returns true or false depending on whether the specified page is displayed. You can use a page
  # object or a PageObject class name to identify the page you are looking for. Examples:
  #
  #  page = site.account_summary_page
  #  =>#<AccountSummaryPage:70341126478080 ...>
  #  site.on_page? page
  #  =>true
  #
  #  site.on_page? AccountSummaryPage
  #  =>true
  def on_page?(page_arg)
    if @browser.is_a? Watir::Browser
      url = @browser.url
    elsif @browser.is_a? Selenium::WebDriver::Driver
      url = @browser.current_url
    else
      raise SiteObject::BrowserLibraryNotSupportedError, "Unsupported browser library: #{@browser.class}"
    end

    if page_arg.url_matcher && page_arg.url_matcher =~ url
      return true
    elsif page_arg.url_template.match url
      return true
    else
      return false
    end
  end

  # Can be used to open a browser for the site object if the user did not pass one in when it was
  # initialized. The arguments used here get passed down to Watir when starting the browser. Example:
  #  s = SomeSite.new(hash)
  #  s.open_browser :watir, :firefox
  def open_browser(platform, browser_type, args={})
    case platform
    when :watir
      @browser = Watir::Browser.new(browser_type, args)
    when :selenium
      @browser = Selenium::WebDriver::Driver.for(browser_type, args)
    else
      raise ArgumentError "Platform argument must be either :watir or :selenium."
    end
  end

  # Looks at the page currently being displayed in the browser and tries to return a page object for
  # it. Does this by looking at the currently displayed URL in the browser. The first page that gets
  # checked is the page that was most recently accessed. After that it will cycle through all available
  # pages looking for a match. Returns nil if it can't find a matching page object.
  def page
    return @most_recent_page if @most_recent_page && @most_recent_page.on_page?

    if @browser.is_a? Watir::Browser
      url = @browser.url
    elsif @browser.is_a? Selenium::WebDriver::Driver
      url = @browser.current_url
    else
      raise SiteObject::BrowserLibraryNotSupportedError, "Unsupported browser library: #{@browser.class}"
    end

    found_page = nil
    @pages.each do |p|
      if p.url_matcher && p.url_matcher =~ url
        found_page = p
      elsif p.query_arguments && p.url_template.match(url)
        found_page = p
      elsif !p.query_arguments && p.url_template.match(url.split(/(\?|#)/)[0])
        found_page = p
      end

      break if found_page
    end

    if found_page && !found_page.required_arguments.empty?
      if hsh = found_page.url_template.extract(url)
        return found_page.new(self, found_page.url_template.extract(url))
      else
        return found_page.new(self, found_page.url_template.extract(url.split(/(\?|#)/)[0]))
      end
    elsif found_page
      return found_page.new(self)
    else
      return nil
    end
  end

  at_exit { @browser.close if @browser }
end
