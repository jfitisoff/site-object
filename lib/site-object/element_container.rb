class ElementContainer
  attr_accessor :element

  def initialize(element)
    @element = element
  end

  def method_missing(sym, *args, &block)
    @element.send(sym, *args, &block)
  end

end
