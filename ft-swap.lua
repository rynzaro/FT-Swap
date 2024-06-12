---@diagnostic disable: undefined-global, undefined-field
local bint = require('.bint')(256)
local ao = require('ao')

ReceivedTokens = ReceivedTokens or {}
OpenOrders = OpenOrders or {}
CurrentId = CurrentId or 0

Handlers.add(
    'receiveDeposit',
    Handlers.utils.hasMatchingTag('Action', 'Credit-Notice'),
    function(msg)
        local depositContractId = msg.From
        local sender = msg.Tags.Sender
        local quantity = bint(msg.Tags.Quantity)

        if not ReceivedTokens[depositContractId] then
            --if contract ID has n record, create it
            print('Register Contract ID')
            ReceivedTokens[depositContractId] = {[sender] = tostring(quantity)}
        else
            if not ReceivedTokens[depositContractId][sender] then
                print('Sender is depositing this currency for the first time')
                ReceivedTokens[depositContractId][sender] = tostring(quantity)
            else
                print('Updating deposit for existing sender.')
                ReceivedTokens[depositContractId][sender] = tostring(bint.__add(quantity, bint(ReceivedTokens[depositContractId][sender])))
            end
        end
        ao.send({
            Target = msg.Tags.Sender,
            Action = 'Deposit-Notice',
            Data = 'Succesfully deposited ' .. tostring(quantity) .. ' tokens from fungible token process ' .. msg.From,
            Balance = tostring(ReceivedTokens[depositContractId][sender])
        })
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

        -- we wanna handle that through an error message
        assert(tonumber(ReceivedTokens[msg.FromContract][msg.From]) >= tonumber(msg.FromAmount), 'balance must be higher than token amount to exchange from')
        if not ReceivedTokens[msg.FromContract][msg.From] then
            ao.send({
                Target = msg.From,
                Action = 'Make-Order-Error',
                Data = 'Sender does not have a registered balance',
            })
        end
        local sender = msg.From
        local sender_balance = ReceivedTokens[msg.FromContract][sender]

        -- Check if maker has enough balance

        local order = {
            OrderId = CurrentId,
            Maker = msg.From,
            FromContract = msg.FromContract,
            ToContract = msg.ToContract,
            FromAmount = msg.FromAmount,
            ToAmount = msg.ToAmount,
        }

        ReceivedTokens[msg.FromContract][sender] = sender_balance - msg.FromAmount

        OpenOrders[CurrentId] = order
        CurrentId = CurrentId + 1;
        ao.send({
            Target = msg.From,
            Action = 'Make-Order-Success',
            Data = 'Succesfully create an order with the id ' .. order.OrderId,
        })
    end
)

Handlers.add(
    'receiveTake',
    Handlers.utils.hasMatchingTag('Action', 'Take-Order'),
    function(msg)
        assert(type(msg.OrderId) == 'string', 'Need to input OrderId')
        local id = tonumber(msg.OrderId)
        -- assign Order to a local order variable
        local order = OpenOrders[id]

        if not order then
            print('The order does not exist')
            return
        end

        local toAmount = bint(order.ToAmount)
        local maker = msg.From

        -- check if taker balance is high enough
        local takerBalance = bint(ReceivedTokens[order.ToContract][maker])
        if not bint.__le(toAmount, takerBalance) then
            print('Balance is lower than requested token amount')
            return
        else
        -- if balance is high enough, deduct amount from the balance
            print(tostring(takerBalance))
            ReceivedTokens[order.ToContract][maker] = tostring(bint.__sub(takerBalance, toAmount))
            -- send maker's deposit to taker
            print('Sending taker deposit to maker...')
            ao.send({
                Target = order.ToContract,
                Action = 'Transfer',
                Recipient = order.Maker,
                Quantity = order.ToAmount,
            })

            -- send taker's deposit to maker
            print('Sending maker deposit to taker...')
            ao.send({
                Target = order.FromContract,
                Action = 'Transfer',
                Recipient = msg.From,
                Quantity = order.FromAmount,
            })
            -- delete order from the open order array
            print('Deleting Order')
            OpenOrders[id] = nil
        end
    end
)

Handlers.add(
    'printOrder',
    Handlers.utils.hasMatchingTag('Action', 'Print-Order'),
    function(msg)
        assert(type(msg.OrderId) == 'string', 'You need to input an Order ID')
        orderId = tonumber(msg.OrderId)
        assert(orderId < CurrentId, 'You need to pick an Id that is lower than the current once: '.. CurrentId)
        print(OpenOrders[orderId])

    end
)

Handlers.add(
    'printOrders',
    Handlers.utils.hasMatchingTag('Action', 'Print-Orders'),
    function(msg)
        for key, order in pairs(OpenOrders) do
            print(order)
        end
    end

)