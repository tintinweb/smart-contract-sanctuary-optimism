# @version 0.3.9

# A rating is a uint8 between 1 and 5
# Contract addresses are associated with ratings via mappings

ratingData: public(HashMap[address, HashMap[address, uint8]])
ratingSum: public(HashMap[address, uint256])
ratingCount: public(HashMap[address, uint256])

@external
def store(_contract: address, _rating: uint8) -> bool:
    """
    Function to store rating into the blockchain
    """
    assert _rating >= 1 and _rating <= 5, "Invalid rating. Rating should be between 1 and 5"
    # When updating the rating, adjust the sum and count of the ratings
    previousRating: uint8 = self.ratingData[msg.sender][_contract]
    # handle the case when a rating is being updated and the new rating is lower
    if previousRating > _rating:
        self.ratingSum[_contract] -= convert(previousRating - _rating, uint256)
    else:
        self.ratingSum[_contract] += convert(_rating - previousRating, uint256)

    if previousRating == 0:
        self.ratingCount[_contract] += 1
    self.ratingData[msg.sender][_contract] = _rating
    return True

@external
def get(_contract: address) -> uint8:
    """
    Function to retrieve stored rating from the blockchain
    """
    return self.ratingData[msg.sender][_contract]

@view
@external
def getAverageRating(_contract: address) -> decimal:
    """
    Function to retrieve average rating of the contract from the blockchain
    """
    # Check if there are any ratings for the contract
    assert self.ratingCount[_contract] != 0, "No ratings available for this contract"
    sumDec: decimal = convert(self.ratingSum[_contract], decimal)
    countDec: decimal = convert(self.ratingCount[_contract], decimal)
    averageRating: decimal = sumDec / countDec
    return averageRating