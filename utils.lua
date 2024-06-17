FromContract = '5toZ7TMmA5OC4tAUcmcdPCiZ3HMLZNzTFz6zOQnvZkM'
ToContract = 'MLkkESmb_B2uFlqY9m0EDoeZtfGRUryKo_uiijgr0q8'
SwapContract = 'VHSRGkEDLJgVvDmwtECR_oH_ty731PSeRyUsAgc1FvI'

function GetBalance(contractId)
    ao.send({
        Target = contractId,
        Action = 'Balance'
    })
end

function Transfer(contract, recipient, quantity)
    ao.send({
        Target = contract,
        Action = 'Transfer',
        Recipient = recipient,
        Quantity = quantity
    })
end

function MakeOrder(fromContract, fromAmount, toContract, toAmount)
    ao.send({
        Target = SwapContract,
        Action = 'Make-Order',
        FromContract = fromContract,
        FromAmount = fromAmount,
        ToContract = toContract,
        ToAmount = toAmount
    })
end

function TakeOrder(orderId)
    ao.send({
        Target = SwapContract,
        Action = 'Take-Order',
        OrderId = orderId
    })
end