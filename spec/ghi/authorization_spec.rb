require "ghi"

describe GHI::Authorization do
  describe "token" do
    context "given an empty string" do
      subject {GHI::Authorization::Required.new}
      it "moo" do
        expect(subject.message()).to eql("Authorization required.")
      end
      it "returns zero" do
        expect(GHI::Authorization.token()).to eql(nil)
      end
    end
  end
end
