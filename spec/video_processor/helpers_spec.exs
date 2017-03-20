defmodule VideoProcessor.HelpersSpec do
  use ESpec

  describe "parse_xml_item" do
    let :xml, do: Path.join([File.cwd!, "spec", "fixtures", "example.xml"]) |> File.read!
    let :item, do: Floki.find(xml(), "item") |> List.first

    context "when element exist" do
      it do: expect described_module().parse_xml_item(item(), "guid") |> to(eq "p5Y29lYTE63vDjfTopuYXX0oreQ9ZTGV")
    end

    context "when element doesn't exist" do
      it do: expect described_module().parse_xml_item(item(), "undefined") |> to(eq "")
    end
  end
end
