ReceivedTokens = ReceivedTokens or {}
OpenOrders = OpenOrders or {}
CurrentId = CurrentId or 0

Handlers.add(
    'receiveDeposit',
    Handlers.utils.hasMatchingTag('Action', 'Credit-Notice'),
    function(msg)
        local depositContractId = msg.From
        local sender = msg.Tags.Sender
        local quantity = msg.Tags.Quantity

        if not ReceivedTokens[contractFrom] then
            print('Register Contract ID')
            ReceivedTokens[depositContractId] = {[sender] = quantity}
            print('Balance:', ReceivedTokens[depositContractId][sender])
        else
            if not ReceivedTokens[depositContractId][sender] then
                print('Sender is depositing this currency for the first time')
                ReceivedTokens[depositContractId][sender] = quantity
            else
                print('Updating deposit for existing sender.')
                ReceivedTokens[depositContractId][sender] = quantity + ReceivedTokens[depositContractId][sender]
        end
    end
end
)

Handlers.add(
    'receiveMake',
    Handlers.utils.hasMatchingTag('Action', 'Make-Order'),
    function(msg)
        assert(type(msg.FromContract) == 'string', 'Need to input contract address to exchange from!')
        assert(type(msg.ToContract) == 'string', 'Need to input contract address to exchange to!')
        assert(type(msg.FromAmount) == 'string', 'Need to input amount to exchange from!')
        assert(type(msg.ToAmount) == 'string', 'Need to input amount to exchange to!')
        local sender = msg.From

        -- Check if maker has enough balance
        assert(ReceivedTokens[msg.FromContract][sender] >= msg.FromAmount, 'maker does not have enough balance')


        order = {
            OrderId = CurrentId,
            FromContract = msg.FromContract,
            ToContract = msg.ToContract,
            FromAmount = msg.FromAmount,
            ToAmount = msg.ToAmount,
        }

        OrderId = CurrentId
        CurrentId = CurrentId + 1;
        print('Created order with order id '.. orderId)
        OpenOrders[OrderId] = {order}
    end
)