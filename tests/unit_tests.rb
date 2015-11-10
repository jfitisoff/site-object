describe "POC" do
  before(:all) do
    @b = Watir::Browser.new
  end

  # after(:all) do
  #   @b.close
  # end

  it "runs a browser test" do
    @b.goto("https://www.google.com/")
    expect(@b.text).to match /gmail/i
  end
end
