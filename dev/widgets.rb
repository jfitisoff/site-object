module WidgetMethods
end

# Allows the page object developer to encapsulate common web application features
# into a "widget" that can be reused across multiple pages. Let's say that a
# web application has a search widget that is used in 11 of the application's pages.
# With a modern web app all of those search widgets will likely be implemented
# in a common way, with a similar or identical structure in the HTML. The widget
# would look something like this:
#
#  class SearchWidget < Widget
#    text_field :query, id: 'q'
#    button :search_button, name: 'Search'
#
#    def search(search_query)
#      query.set search_query
#      search_button.click
#    end
#
#    def clear
#      query.set ''
#      search_button.click
#    end
#  end
#
# Once the widget has been defined, it can be included in a page object definition
# like this:
#
#  class SomePage < SomeSite::Page
#    set_url 'some_page'
#    search_widget :search_for_foo, :div, class: 'search-div'
#  end
#
# The search widget can then be accessed like this when working with the site:
#  site.some_page.search_for_foo 'some search term'
#  site.search_for_foo.clear
#
# Widgets can be embedded in other widgets, but in that case, the arguments for
# accessing the child widget need to be RELATIVE to the parent widget. For example:
#
#  # Generic link menu, you hover over it and one or more links are displayed.
#  class LinkMenu < Widget
#  end
#
#  # Card widget that uses the link_menu widget. In this case, link_menu widget
#  # arguments will be used to find a div a div with class == 'card-action-links'
#  # WITHIN the card itself. This ensures that, if there are multiple cards
#  # on the page that have link_menus, the CORRECT link_menu will be accessed
#  # rather than one for some other card widget.
#  class Card < Widget
#    link_menu :card_menu, :div, class: 'card-action-links'
#  end
class Widget
  attr_reader :site, :browser, :type, :args, :target

  class << self
    include WidgetMethods

    # Adds class-level Watir DOM methods to the widget for defining page
    # elements.
    WATIR_METHODS.each do |mth|
      define_method(mth) do |name=nil, *args, &block|
        if block
          element_container(name, mth, *args, &block)
        else
          el(name) { |b| b.send(mth, parse_args(args.flatten)) }
        end
      end
    end

    # private
    # def parse_args(args)
    #   case args.length
    #   when 2
    #     return { args[0] => args[1] }
    #   when 1
    #     obj = args.first
    #   return obj if obj.kind_of? Hash
    #   when 0
    #     return {}
    #   end
    # end
    # public
    #
    # WATIR_METHODS.each do |mth|
    #   define_method(mth) do |name=nil, *args|
    #     send(mth, parse_args(args.flatten))
    #   end
    # end

    # - Don't allow the user to create a widget with a name that matches a DOM
    #   element.
    #
    # - Don't allow the user to create a widget method that references a
    #   collection (because this will be done automatically.)
    tmp = name.to_s.underscore.to_sym
    if WATIR_METHODS.include?(name.to_s.underscore.to_sym)
      raise "#{name} cannot be used as a widget name, as the methodized version of the class name (#{name.to_s.underscore} conflicts with a Watir DOM method.)"
    elsif Watir::Browser.methods.include?(name.to_s.underscore.to_sym)
      raise "#{name} cannot be used as a widget name, as the methodized version of the class name (#{name.to_s.underscore} conflicts with a Watir::Browser method.)"
    end

    if tmp =~ /.*s+/
      raise "Invalid widget type :#{tmp}. You can create a widget for the DOM object but it must be for :#{tmp.singularize} (:#{tmp} will be created automatically.)"
    end
  end # Self.

  extend Forwardable

  # Creates class methods for widgets. These methods are then used to reference
  # the widget when defining page objects. For each widget that gets defined,
  # singular and pluralized versions of the method will be created, one for an
  # individual instance of the widget and another for a collection. For example,
  # defining a Foobar widget will result in 2 class methods that can be used when
  # defining page objects called :foobar and :foobars. Either one or both of those
  # could be used when defining a page object.
  def self.inherited(subclass)
    name_string            = subclass.name.demodulize.underscore
    pluralized_name_string = name_string.pluralize

    if name_string == pluralized_name_string
      raise ArgumentError, "When defining a new widget, define the singular version only (Plural case will be handled automatically.)"
    end

    # tmp = Object.const_set(pluralized_name_string, subclass)

    # Adds class-level widget methods.
    #[name_string, pluralized_name_string].each do |method_name|
    WidgetMethods.send(:define_method, name_string) do |method_name, dom_type, *args, &block|
      if block_given?
        subclass.class_eval { block.call }
      end

      define_method(method_name) do
        if is_a? Widget
          elem = send(dom_type, *args, &block)
        else
          elem = @browser.send(dom_type, *args, &block)
        end

        if elem.is_a?(Watir::ElementCollection) || elem.is_a?(Watir::HTMLElementCollection)
          raise ArgumentError, "Individual widget method :#{method_name} cannot initialize a widget using an element collection (#{elem.class}.) Use :#{method_name.pluralize} rather than :#{method_name} if you want to define a widget collection."
        else
          subclass.new(self, dom_type, *args, &block)
        end
      end
    end

    WidgetMethods.send(:define_method, pluralized_name_string) do |method_name, dom_type, *args, &block|
      if block_given?
        subclass.class_eval { block.call }
      end

      define_method(method_name) do
        if is_a? Widget
          elem = send(dom_type, *args, &block)
        else
          elem = @browser.send(dom_type, *args, &block)
        end

        if elem.is_a?(Watir::Element) || elem.is_a?(Watir::HTMLElement)
          raise ArgumentError, "Widget collection method :#{method_name} cannot initialize a widget collection using an individual element (#{elem.class}.) Use :#{method_name.singularize} rather than :#{method_name} if you want to define a widget for an individual element."
        else
          elem.to_a.map! { |x| subclass.new(self, x, [], &block) }
        end
      end
    end
  end # self.

  # This method gets used 2 different ways. Most of the time, dom_type and args
  # will be a symbol and a set of hash arguments that will be used to locate an
  # element.
  #
  # In some cases, dom_type can be a Watir DOM object, and in this case, the
  # args are ignored and the widget is initialized using the Watir object.
  #
  # TODO: Needs a rewrite, lines between individual and collection are blurred
  # here and that makes the code more confusing. And there should be a proper
  # collection class for element collections, with possibly some AR-like accessors.
  def initialize(parent, dom_type, *args)
    @parent   = parent
    @site     = parent.class.ancestors.include?(SiteObject) ? parent : parent.site
    @browser  = @site.browser

    if dom_type.is_a?(Watir::HTMLElement) || dom_type.is_a?(Watir::Element)
      @dom_type = nil
      @args     = nil
      @target   = dom_type.to_subtype
    elsif [String, Symbol].include? dom_type.class
      @dom_type = dom_type
      @args     = args

      if @parent.is_a? Widget
        @target = @parent.send(dom_type, *args)
      else
        @target = @browser.send(dom_type, *args)
      end
    elsif dom_type.is_a? Watir::ElementCollection
      @dom_type = nil
      @args     = nil
      if @parent.is_a? Widget
        @target = dom_type.map { |x| self.class.new(@parent, x.to_subtype) }
      else
        @target = dom_type.map { |x| self.class.new(@site, x.to_subtype) }
      end
    else
      raise "Unhandled."
    end
  end

  # Delegates method calls down to the widget's wrapped element if the element supports the method.
  #
  # Supports dynamic link methods. Examples:
  #  s.accounts_page account
  #
  #  # Nav to linked page only.
  #  s.account_actions.edit_account_info
  #
  #  # Update linked page after nav:
  #  s.account_actions.edit_account_info username: 'foo'
  #
  #  # Link with modal (if the modal requires args they should be passed as hash keys):
  #  # s.hosted_pages.refresh_urls
  # TODO:
  #
  # - Forms within cards? (/accounts/:account_code account notes section.)
  # - Static method for email links.
  def method_missing(mth, *args, &block)
    if @target.respond_to? mth
      return @target.send(mth, *args, &block)
    else
      if args[0].is_a? Hash
        page_arguments = args[0]#.with_indifferent_access
        error_check    = page_arguments.delete(:error_check)
      elsif args[0].nil?
        # Do nothing.
      else
        raise ArgumentError, "Optional argument must be a hash (got #{args[0].class}.)"
      end

      if present?
        widget_links = as
      else
        widget_links = []
      end

      if mth.to_s =~ /_link$/
        return a(text: /^#{mth.to_s.sub(/_link$/, '').gsub('_', ' ')}/i)
      elsif lnk = widget_links.find { |x| x.text =~ /^#{mth.to_s.gsub('_', ' ')}/i }
        lnk.when_present(3)
        lnk.click
        sleep 1

        if @site.modal.present?
          @site.modal.continue(page_arguments)
        else
          current_page = @site.page

          if page_arguments.present?
            if error_check != false
              if tmp = @site.page_errors
                raise tmp.to_s
              end
            end

            if current_page.respond_to?(:submit)
              current_page.submit page_arguments
            elsif @browser.input(xpath: "//div[starts-with(@class,'Row') and last()]//input[@type='submit' and last()]").present?
              current_page.update_page page_arguments
              @browser.input(xpath: "//div[starts-with(@class,'Row') and last()]//input[@type='submit' and last()]").click
            end
            current_page = @site.page
          end
        end
      else
        super
      end
    end

    if error_check != false
      if tmp = @site.page_errors
        raise tmp.to_s
      end
    end

    page_arguments.present? ? page_arguments : current_page
  end

  def nokogiri
    Nokogiri::HTML(html)
  end

  def present?
    @target.present?
  end
end
