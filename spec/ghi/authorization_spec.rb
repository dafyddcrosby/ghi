require "ghi"

describe GHI::Authorization do
  describe "token" do
    context "given an empty string" do

      it "returns zero" do
        expect(GHI::Authorization.token()).to eql(nil)
      end
    end
  end
end
