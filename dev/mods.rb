class ElementContainer
  attr_reader :target

  class << self
    # Implement the same argument parsing the Watir::HTMLElement does because we're
    # doing a pass-through.
    private
    def parse_args(args)
      case args.length
      when 2
        return { args[0] => args[1] }
      when 1
        obj = args.first
      return obj if obj.kind_of? Hash
      when 0
        return {}
      end
    end
    public

    WATIR_METHODS.each do |mth|
      define_method(mth) do |name=nil, *args|
        el(name) { |b| b.send(mth, parse_args(args.flatten)) }
      end
    end

    # For ElementContainer.
    def el(name, &block)
      @page_elements ||= []
      @page_elements << name.to_sym

      define_method(name) do
        begin
          block.call(@target)
        rescue(Watir::Exception::UnknownObjectException) => e
          tmp = page

          if tmp == @most_recent_page
            raise e
          else
            @most_recent_page = tmp
            block.call(@target)
          end
        end
      end
    end
  end # self

  def initialize(element)
    @target = element
  end

  def nokogiri
    Nokogiri::HTML(html)
  end

  # For page widget code.
  def method_missing(sym, *args, &block)
    if @target.respond_to? sym
      if @target.is_a? Watir::ElementCollection
        @target.map { |x| self.class.new(x) }.send(sym, *args, &block)
      else
        @target.send(sym, *args, &block)
      end
    else
      super
    end
  end
end

module PageObject

  module PageClassMethods

    # Adds all of the Watir DOM methods as class-level methods that can be used in
    # place of Page::element/el. Example:
    #
    # # Old way (Still supported.)
    # el(:foo_div) { |b| b.div(:id, 'foo') }
    #
    # # The new methods mirror the behavior of the Watir::Browser methods. You can
    # # either provide :how and :what arguments or a hash of values. The following
    # # two examples are functionally equivalent:
    # div(:foo_div, :id:, 'foo') # :how and :what arguments to identify something one way.
    # div( :foo_div, :id: 'foo') # Hash argument to identify something multiple ways.
    # WATIR_METHODS.each do |mth|
    #   define_method(mth) do |name=nil, *args|
    #     el(name) { |b| b.send(mth, parse_args(args.flatten)) }
    #   end
    # end

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
    def element_container(name, type, *args, &block)
      tmpklass = Class.new(ElementContainer) do
        self.class_eval(&block) if block_given?
      end

      cname = name.to_s.camelcase + 'Container'
      const_set(cname, tmpklass) unless const_defined? cname

      @page_elements ||= []
      @page_elements << name.to_sym

      define_method(name) do
        self.class.const_get(cname).send(:new, @browser.send(type, *args))
      end
    end
    # public

    def section(name, klass = Section, &block)
      tmpklass = Class.new(klass) do
        self.class_eval(&block) if block_given?
      end
      const_set(name.to_s.camelcase, tmpklass) unless const_defined? name.to_s.camelcase

      define_method(name.to_s.underscore) do
        tmpklass.new(page = self)
      end
    end

    # Implement the same argument parsing the Watir::HTMLElement does because we're
    # doing a pass-through.
    private
    def parse_args(args)
      case args.length
      when 2
        return { args[0] => args[1] }
      when 1
        obj = args.first
      return obj if obj.kind_of? Hash
      when 0
        return {}
      end
    end
    public

    def widget_method(method_name, widget_symbol, widget_method, target_element)
      define_method(method_name) do |*args, &block|
        self.class.const_get(widget_symbol.to_s.camelize)
          .new(@site, @site.send(target_element))
          .send(widget_method, *args, &block)
        # widget_symbol.to_s.camelize.constantize.new(@site, @site.send(target_element).send(widget_method, *args, &block)
      end
    end

  end # End PageClassMethods module.

  module PageInstanceMethods

    # EXPERIMENTAL, only tested with Watir. A simple mechanism to assist in cases where you need to
    # update a page that has a form. This method takes a Hash argument. Keys should be the names of
    # page element methods. Values should be one of the following:
    # -String: The method will assume that you're trying to set a text field or select a value in a
    # select list.
    # -Symbol: The method will assume that you're trying to set or clear something and will pass the
    #  Symbol you've specified along to the thing you're accessing.
    # -Regexp: The method will assume you're trying to select something in a select list and will
    #  try to do that using the Regexp that has been specified.
    #
    # Example: You have a form on a page that has text fields to specify a first name, last name,
    # email address and whether or not to subscribe to a company newsletter. You've defined each of
    # these HTML elements in your page class. You could use this method to update the form on this
    # page in the following manner:
    #
    # page.update_page(
    #   first_name: 'Jar Jar',
    #   last_name:  'Binks',
    #   subscribe_to_newsletter: :set
    # )
    #
    # Note that there's no call to submit the form in this example although you could include that
    # in the method call if the option to submit has been defined as a page element in the page class.
    # This is by design. The intent is to provide a base setter method for the page that can be
    # wrapped up in a higher-level 'create' or 'edit' method for the page because there may be some
    # situations where you don't actually want to submit the form after populating it.
    def update_page(args={}) # test
      failed = []
      args.each do |k, v|
        begin
          k = k.to_sym
          if page_elements.include?(k)
            Watir::Wait.until(15) { self.send(k).present? }
            tmp = self.send(k)
            # tmp.when_present(15) if tmp.respond_to? :when_present
            if tmp.is_a? Watir::WhenPresentDecorator
              html_element = tmp.instance_variable_get(:@element)
            else
              html_element = tmp
            end

            if [Watir::Alert, Watir::FileField, Watir::TextField, Watir::TextArea].include? html_element.class
              html_element.set v
            elsif [Watir::Select].include? html_element.class
              html_element.select v
            elsif [Watir::Anchor, Watir::Button].include? html_element.class
              case v
              when Symbol
                html_element.send v
              when TrueClass
                html_element.click
              when FalseClass
                # Do nothing here.
              else
                raise ArgumentError, "Unsupported argument for #{html_element.class}: '#{v}'"
              end
            elsif html_element.is_a?(Watir::RadioCollection)
              rb = html_element.to_a.find do |r|
                r.text =~ /#{Regexp.escape(v)}/i || r.parent.text =~ /#{Regexp.escape(v)}/i
              end

              if rb
                rb.click
              else
                raise "No matching radio button could be detected for '#{val}' for #{html_element}."
              end
            else
              case v
              when Symbol
                html_element.send v
              when TrueClass
                html_element.set
              when FalseClass
                html_element.clear
              else
                raise ArgumentError, "Unsupported argument for #{html_element.class}: '#{v}'"
              end
            end
          else
            # Temporary band-aid to support widgets.
            tmp = send(k)

            if tmp.is_a?(Widget) || tmp.is_a?(ElementContainer)
              if tmp.respond_to?(:update)
                tmp.update(*v)
              else
                raise "Cannot update #{tmp.class} (an update method must be added.)"
              end
            else
              raise "Cannot update #{tmp.class}."
            end
          end
        rescue Watir::Exception::ObjectDisabledException, Watir::Exception::UnknownObjectException => e
          unless failed.include?(k)
            puts "Rescued #{e.class} when trying to update #{k}. Sleeping 10 seconds and then trying again."
            failed << k
            sleep 10
            redo
          end
        end
      end
      sleep 1
      args
    end
  end # End PageInstanceMethods module.
end
