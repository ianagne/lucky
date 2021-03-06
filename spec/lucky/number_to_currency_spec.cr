require "../../spec_helper"
require "html"

private class TestPage
  include Lucky::HTMLPage

  def render
  end
end

describe Lucky::NumberToCurrency do
  describe "number_to_currency" do
    it "accepts Float" do
      view.number_to_currency(29.92).to_s.should eq(HTML.escape("$29.92"))
    end

    it "accepts String" do
      view.number_to_currency("92.29").to_s.should eq(HTML.escape("$92.29"))
    end

    it "accepts Integer" do
      view.number_to_currency(92).to_s.should eq(HTML.escape("$92.00"))
    end

    describe "options" do
      it "accepts precision" do
        view.number_to_currency(29.929123, precision: 3).to_s.should eq(HTML.escape("$29.929"))
      end

      it "accepts unit" do
        view.number_to_currency(29.92, unit: "CAD").to_s.should eq "CAD29.92"
      end

      it "accepts separator" do
        view.number_to_currency(29.92, separator: "-").to_s.should eq(HTML.escape("$29-92"))
      end

      it "accepts delimiter" do
        view.number_to_currency(1234567890.29, delimiter: "-").to_s.should eq(HTML.escape("$1-234-567-890.29"))
      end

      it "accepts delimiter pattern" do
        view.number_to_currency(1230000, delimiter_pattern: /(\d+?)(?=(\d\d)+(\d)(?!\d))/).to_s.should eq(HTML.escape("$12,30,000.00"))
      end

      it "accepts format" do
        view.number_to_currency("1234567890.50", format: "%n ** %u").to_s.should eq(HTML.escape("1,234,567,890.50 ** $"))
      end

      it "accepts negative format" do
        view.number_to_currency("-1234567890.50", negative_format: "%n ** - %u").to_s.should eq(HTML.escape("1,234,567,890.50 ** - $"))
      end
    end
  end
end

private def view
  TestPage.new(build_context)
end
