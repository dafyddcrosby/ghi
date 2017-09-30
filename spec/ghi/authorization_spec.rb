require "ghi"

describe GHI::Authorization do
  describe "Required" do
    subject {GHI::Authorization::Required.new}
    it "Returns a string" do
      expect(subject.message()).to eql("Authorization required.")
    end
	      
    it "returns zero" do
      expect(GHI::Authorization.token()).to eql(nil)
    end
  end
end
