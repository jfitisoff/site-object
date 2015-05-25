require 'active_support/inflector'
require 'addressable/template'

# Creates a reusable piece of functionality that can be applied to multiple pages. For example, maybe 
# you have a footer that's common to all pages displayed after the user logs into the app:
#
#  class Footer < PageFeature
#    element(:news)       { |b| b.link(:text, 'News') }
#    element(:support)    { |b| b.link(:text, 'Support') }
#    element(:contact_us) { |b| b.link(:text, 'Contact Us') }
#  end
#
#  class TestPage < MySite::Page
#    set_url('/blah')
#    use_features :footer
#  end
#
# The PageObject.use_features method is then used to add the page feature to the classes that you want
# to add it to. Note that the name of the page feature class (Footer) gets added to the class as :footer.
# Once added to the page definition, the footer page feature can then be accessed from the page using the
# 'footer' method.
#
#  mysite.test_page.footer.contact_us.present? # present? is a method supported by Watir.
#  =>true
#
# There may be some cases where you don't want the feature name to be the same as the class name. In these
# sorts of situations you can use the PageFeature.feature_name method to override this behavior.
class PageFeature
  class << self
    attr_accessor :alias

    # Used to define access to a single HTML element on a page. This method takes two arguments:
    #
    # * A symbol representing the element you are defining. This symbol is used to create an accessor method on the
    #   page object.
    # * A block where access to the HTML element gets defined.
    #
    # Example: The page you are working with has a "First Name" field.
    #
    #  element(:first_name) { |b| b.text_field(:id 'signup-first-name') }
    #
    # In this example, 'b' is the browser object that will get passed down from the site to the page and then used
    # when the page element needs to be accessed.
    #
    # The 'element' method is aliased to 'el' and using the alias is recommended as it saves space:
    #
    #  el(:first_name) { |b| b.text_field(:id 'signup-first-name') }
    #
    def element(name, &block)
      define_method(name) do
        block.call(@browser)
      end
    end
    alias :el :element

    # By default, the feature gets imported using the class name of the PageFeature class. For example if you
    # import a PageFeature named Footer, the page will have a 'footer' method that provides access to the News,
    # Support and Contact Us links (see example above.) You can use this method to overwrite the default naming
    # scheme if you need to. In the example below, the footer feature defined here would have a page object
    # accessor method called special_footer:
    #
    #  class Footer < PageFeature
    #    feature_name :special_footer
    #
    #    element(:news)       { |b| b.link(:text, 'News') }
    #    element(:support)    { |b| b.link(:text, 'Support') }
    #    element(:contact_us) { |b| b.link(:text, 'Contact Us') }
    #  end
    def feature_name(name)
      @alias = name
    end

  end
  
  # Not meant to be accessed directly. Use PageObject.use_features to add a PageFeature to a PageObject.
  def initialize(browser, args={})
    @args          = args
    @browser       = browser
  end  
end
