from app.db.session import get_db
from app.models.enums import FriendRequestStatus
from app.models.friend import FriendRequest, friends_association
from app.models.user import User
from fastapi import Depends, HTTPException, status
from sqlalchemy import and_, or_, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import joinedload, selectinload


class CRUDFriend:
    async def send_friend_request(
        self, db: AsyncSession, *, sender_id: int, receiver_id: int
    ):
        existing_request = await db.execute(
            select(FriendRequest).where(
                and_(
                    FriendRequest.sender_id == sender_id,
                    FriendRequest.receiver_id == receiver_id,
                    FriendRequest.status == FriendRequestStatus.PENDING,
                )
            )
        )
        if existing_request.scalar_one_or_none():
            raise HTTPException(status_code=400, detail="Friend request already sent")
        request = FriendRequest(
            sender_id=sender_id,
            receiver_id=receiver_id,
        )
        db.add(request)
        await db.commit()
        await db.refresh(request)
        request = await db.scalar(
            select(FriendRequest)
            .where(FriendRequest.id == request.id)
            .options(
                joinedload(FriendRequest.sender), joinedload(FriendRequest.receiver)
            )
        )
        return request

    async def get_friend_requests(self, db: AsyncSession, *, user_id: int):
        stmt = (
            select(FriendRequest)
            .options(
                selectinload(FriendRequest.sender),  # or joinedload
                selectinload(FriendRequest.receiver),
            )
            .where(
                FriendRequest.receiver_id == user_id,
                FriendRequest.status == FriendRequestStatus.PENDING,
            )
        )
        result = await db.execute(stmt)
        requests = result.scalars().all()
        return requests

    async def respond_to_friend_request(
        self, db: AsyncSession, *, request_id: int, status: FriendRequestStatus
    ):
        request = await db.get(FriendRequest, request_id)
        if not request:
            raise HTTPException(status_code=404, detail="Friend request not found")
        if request.status == FriendRequestStatus.ACCEPTED:
            stmt1 = friends_association.insert().values(
                user_id=request.sender_id, friend_id=request.receiver_id
            )
            stmt2 = friends_association.insert().values(
                user_id=request.receiver_id, friend_id=request.sender_id
            )
            await db.execute(stmt1)
            await db.execute(stmt2)
        request.status = status
        db.add(request)
        await db.commit()
        await db.refresh(request)
        return request

    async def get_friends(self, db: AsyncSession, *, user_id: int):
        stmt = (
            select(User)
            .join(friends_association, friends_association.c.friend_id == User.id)
            .where(friends_association.c.user_id == user_id)
        )

        result = await db.scalars(stmt)
        return result.all()

    async def recommend_friends(
        self,
        current_student: User,
        db: AsyncSession = Depends(get_db),
    ):
        if current_student.role != "student":
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Only students can access this endpoint.",
            )
        filter = []

        if current_student.school_name:
            filter.append(User.school_name == current_student.school_name)
        if current_student.city:
            filter.append(User.city == current_student.city)
        if current_student.grade_level:
            filter.append(User.grade_level == current_student.grade_level)

        if not filter:
            stmt = (
                select(User)
                .where(
                    User.role == "student",
                    User.id != current_student.id,
                    # User.is_active == True,
                )
                .limit(10)
            )
        else:
            stmt = (
                select(User)
                .where(
                    User.role == "student",
                    User.id != current_student.id,
                    # User.is_active == True,
                    or_(*filter),
                )
                .order_by(
                    User.school_name == current_student.school_name,
                    User.city == current_student.city,
                    User.grade_level == current_student.grade_level,
                )
                .limit(10)
            )

        result = await db.execute(stmt)
        recommendations = result.scalars().all()
        return recommendations


friend_crud = CRUDFriend()
