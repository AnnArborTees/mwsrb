require "spec_helper"

describe Mwsrb do
  it "has a version number" do
    expect(Mwsrb::VERSION).not_to be nil
  end

  describe 'Mwsrb::Api#resolve_lists' do
    subject { Mwsrb::Api.new(:Testing) }

    it "turns hashes in the form [{ Id: 'ASDFG' }, { Id: 'FDDSAG' }] "\
       "to { Id.1: 'ASDFG', Id.2: 'FDDSAG' }" do
      expect(subject.send(:resolve_lists, {IdList: [{ Id: 'ASDFG' }, { Id: 'FDDSAG' }]}))
        .to eq({ 'IdList.Id.1' => 'ASDFG', 'IdList.Id.2' => 'FDDSAG' })
    end
  end
end
