require "spec_helper"

describe Mwsrb do
  it "has a version number" do
    expect(Mwsrb::VERSION).not_to be nil
  end

  describe 'Mwsrb::Api#resolve_lists' do
    subject { Mwsrb::Api.new(:Testing) }

    it "turns hashes in the form [{ Id: 'ASDFG' }, { Id: 'FDDSAG' }] "\
       "to { Id.1: 'ASDFG', Id.2: 'FDDSAG' }" do
      expect(subject.send(:resolve_lists_and_dates, {IdList: [{ Id: 'ASDFG' }, { Id: 'FDDSAG' }]}))
        .to eq({ 'IdList.Id.1' => 'ASDFG', 'IdList.Id.2' => 'FDDSAG' })
    end

    it "turns array values in the form OrderId: ['ASDFG', 'FDDSAG'] "\
       "to { OrderId.Id.1: 'ASDFG', OrderId.Id.2: 'FDDSAG' }" do
      expect(subject.send(:resolve_lists_and_dates, {IdList: [{ Id: 'ASDFG' }, { Id: 'FDDSAG' }]}))
        .to eq({ 'IdList.Id.1' => 'ASDFG', 'IdList.Id.2' => 'FDDSAG' })
    end
  end

  describe 'Mwsrb::Api#element_name' do
    subject { Mwsrb::Api.new(:Testing) }

    it "turns 'OrderId' into 'Id'" do
      expect(subject.send(:element_name, "OrderId")).to eq 'Id'
    end

    it "turns 'ItemStatus' into 'Status'" do
      expect(subject.send(:element_name, "ItemStatus")).to eq 'Status'
    end
  end
end
